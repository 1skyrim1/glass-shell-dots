pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The capture tool's state (DESIGN.md §3.7, 21–24); surfaces/Capture.qml draws it.
//
// Opening hides toasts and OSDs (§4: they're never in a capture), then grim freezes the focused monitor into
// a PPM in $XDG_RUNTIME_DIR. The tool shows that frame 1:1, the loupe and the colour picker read its pixels,
// and a screenshot is an exact ffmpeg crop of it. With a delay the tool closes, a countdown runs over the live
// screen and grim takes the live screen instead. Recordings hand the rectangle to Recorder.
//
// Selections are kept in physical pixels of the monitor (what the size readout shows, and what gets cropped);
// the surface divides by `monitor.scale` to draw them.
Singleton {
    id: root

    // "" closed · "freezing" grabbing the frame · "open" the tool · "shooting" capture flash + fly ·
    // "countdown" delay before a shot or a recording (live screen)
    property string phase: ""
    readonly property bool active: phase !== ""
    readonly property bool hiding: active
    property string tool: "capture"   // "capture" | "color" (Super+Shift+C)

    // --- Options (kept for the session)
    property string mode: "region"    // region | window | screen
    property string kind: "photo"     // photo | video
    property int delay: 0             // s: 0 / 3 / 5 (D)
    property string output: "both"    // both (copy + save) | copy | save (O)
    property bool mic: true
    property bool desktopAudio: true
    property bool cursor: false
    property int fps: 60
    property string format: "mp4"
    readonly property var delays: [0, 3, 5]
    readonly property var outputs: ["both", "copy", "save"]
    readonly property var outputNames: ({ both: "Copy + save", copy: "Copy", save: "Save" })
    readonly property var formats: [[60, "mp4"], [30, "mp4"], [60, "mkv"], [30, "mkv"]]

    function setMode(m: string) { if (m !== "") mode = m }
    function cycleDelay() { delay = delays[(delays.indexOf(delay) + 1) % delays.length] }
    function cycleOutput() { output = outputs[(outputs.indexOf(output) + 1) % outputs.length] }
    function cycleFormat() {
        const i = formats.findIndex(f => f[0] === fps && f[1] === format)
        const next = formats[(i + 1) % formats.length]
        fps = next[0]
        format = next[1]
    }

    // --- The frozen monitor: name, global logical position, physical size, scale
    property var monitor: ({ name: "", x: 0, y: 0, width: 1920, height: 1080, scale: 1 })
    property string freezeFile: ""    // being written by grim
    property string frame: ""         // the frozen frame on screen (set once grim is done)
    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") + "/glass-shell"

    // Region selection (physical px). The last one stays for the next time.
    property var selection: ({ x: 0, y: 0, w: 0, h: 0 })
    // Windows on the monitor's visible workspaces, front first, in physical px relative to the monitor.
    property var windows: []
    property int targetIndex: -1
    readonly property var target: targetIndex >= 0 && targetIndex < windows.length ? windows[targetIndex] : null
    // Cursor in physical px relative to the monitor (loupe, colour picker); arrows nudge it.
    property point cursorPos: Qt.point(0, 0)

    // Colour picker: the pixel under the cursor (read by the surface) and the shown format.
    property color pickColor: "black"
    property string pickFormat: "hex"   // hex | rgb | hsl (Tab)
    function cyclePickFormat() { pickFormat = ({ hex: "rgb", rgb: "hsl", hsl: "hex" })[pickFormat] }

    // The rectangle a capture would take (physical px, monitor-relative).
    readonly property var rect: mode === "screen" ? { x: 0, y: 0, w: monitor.width, h: monitor.height }
        : mode === "window" ? (target ? clip(target) : null)
        : selection.w >= 2 && selection.h >= 2 ? selection : null
    function clip(r: var): var {
        const x = Math.max(0, r.x), y = Math.max(0, r.y)
        return { x: x, y: y, w: Math.min(monitor.width, r.x + r.w) - x, h: Math.min(monitor.height, r.y + r.h) - y }
    }

    // Last screenshot, for the thumbnail card (bottom-left, 6 s) and Annotate.
    property string lastShot: ""
    property bool lastSaved: false    // false = only in the clipboard (a temp file)
    property bool lastCopied: false
    property var lastSize: ({ w: 0, h: 0 })
    property real lastTime: 0
    property bool cardShown: false
    // Where the selection flies from (logical px on the screen), for the capture motion.
    property var flyFrom: null

    // Countdown (delay before a shot or a recording): seconds left, and what it's for.
    property int countdown: 0
    property string countdownLabel: ""
    property var pending: null   // what runs when the countdown ends

    // --- Open / close
    // mode "" keeps the last one; kind "photo" | "video" | "" (keep).
    function open(m: string, k: string) {
        if (Recorder.recording || Shell.locked || Shell.promptOpen) return
        if (phase === "open" && tool === "capture") {
            setMode(m)
            if (k !== "") kind = k
            return
        }
        if (phase !== "") return
        tool = "capture"
        setMode(m)
        if (k !== "") kind = k
        freeze()
    }
    function openPicker() {
        if (phase !== "" || Shell.locked || Shell.promptOpen) return
        tool = "color"
        pickFormat = "hex"
        freeze()
    }
    // The share picker's Region tab: the region tool, whose Capture button shares the rectangle instead.
    property bool forShare: false
    function openForShare() {
        if (phase !== "") return
        tool = "capture"
        forShare = true
        mode = "region"
        kind = "photo"
        freeze()
    }

    function close() {
        if (forShare) { forShare = false; Share.regionCancelled() }
        if (phase === "countdown") pending = null
        phase = ""
        countdown = 0
    }

    function freeze() {
        Shell.closeAll()
        phase = "freezing"
        cardShown = false
        // Let toasts and OSDs vanish from the screen before grim reads it.
        freezeDelay.restart()
    }
    Timer {
        id: freezeDelay
        interval: 60
        onTriggered: {
            const name = Hyprland.focusedMonitor?.name ?? ""
            root.freezeFile = `${root.runDir}/freeze-${Date.now()}.ppm`
            grab.command = ["sh", "-c", `
                mkdir -p "$1"; rm -f "$1"/freeze-*.ppm
                grim -t ppm -o "$2" "$3" || exit 1
                hyprctl -j monitors; printf '\\036'; hyprctl -j clients; printf '\\036'; hyprctl -j cursorpos`,
                "sh", root.runDir, name, root.freezeFile]
            grab.running = true
        }
    }
    Process {
        id: grab
        stdout: StdioCollector { id: grabOut }
        onExited: code => {
            if (code !== 0 || root.phase !== "freezing") { root.phase = ""; return }
            root.frame = root.freezeFile
            try {
                const [mons, clients, cur] = grabOut.text.split("\x1e").map(t => JSON.parse(t))
                const name = grab.command[5]
                const m = mons.find(m => m.name === name) ?? mons[0]
                root.monitor = { name: m.name, x: m.x, y: m.y, width: m.width, height: m.height, scale: m.scale, id: m.id }
                const s = m.scale
                const local = (gx, gy) => ({ x: Math.round((gx - m.x) * s), y: Math.round((gy - m.y) * s) })
                // Front first: the special workspace over the normal one, floating over tiled, then focus order.
                root.windows = clients
                    .filter(c => c.mapped && !c.hidden && c.visible !== false && c.monitor === m.id
                            && (c.workspace.id === m.activeWorkspace.id || c.workspace.id === m.specialWorkspace.id))
                    .sort((a, b) => (b.workspace.id < 0) - (a.workspace.id < 0) || b.floating - a.floating
                            || a.focusHistoryID - b.focusHistoryID)
                    .map(c => {
                        const p = local(c.at[0], c.at[1])
                        return { address: c.address, title: c.title, cls: c.class, x: p.x, y: p.y,
                                 w: Math.round(c.size[0] * s), h: Math.round(c.size[1] * s) }
                    })
                const c = local(cur.x, cur.y)
                root.cursorPos = Qt.point(Math.max(0, Math.min(m.width - 1, c.x)), Math.max(0, Math.min(m.height - 1, c.y)))
                root.targetIndex = root.windowAt(root.cursorPos.x, root.cursorPos.y)
                if (root.targetIndex < 0 && root.windows.length > 0) root.targetIndex = 0
                // First time: a centred selection to start from.
                if (root.selection.w < 2 || root.selection.x + root.selection.w > m.width || root.selection.y + root.selection.h > m.height)
                    root.selection = { x: Math.round(m.width * 0.3), y: Math.round(m.height * 0.3), w: Math.round(m.width * 0.4), h: Math.round(m.height * 0.4) }
            } catch (e) {
                console.warn("Capture: bad hyprctl output", e)
            }
            root.phase = "open"
        }
    }

    function windowAt(x: real, y: real): int {
        return windows.findIndex(w => x >= w.x && x < w.x + w.w && y >= w.y && y < w.y + w.h)
    }
    // Tab: next window, front to back.
    function nextWindow(step: int) {
        if (windows.length === 0) return
        targetIndex = ((targetIndex < 0 ? 0 : targetIndex + step) + windows.length) % windows.length
    }

    // Arrows: region mode moves the selection (Shift: 10 px), the colour picker moves the cursor.
    function nudge(dx: int, dy: int) {
        if (tool === "color") {
            cursorPos = Qt.point(Math.max(0, Math.min(monitor.width - 1, cursorPos.x + dx)),
                                 Math.max(0, Math.min(monitor.height - 1, cursorPos.y + dy)))
        } else if (mode === "region") {
            const s = selection
            selection = { x: Math.max(0, Math.min(monitor.width - s.w, s.x + dx)),
                          y: Math.max(0, Math.min(monitor.height - s.h, s.y + dy)), w: s.w, h: s.h }
        }
    }

    // A short name for what's captured ("Discord window", "region", "screen").
    readonly property string targetName: mode === "screen" ? "screen" : mode === "window" ? (target ? appName(target) + " window" : "window") : "region"
    function appName(w: var): string {
        const c = w.cls || w.title || "Window"
        return c.charAt(0).toUpperCase() + c.slice(1)
    }

    // --- Capture (Enter)
    function capture() {
        if (phase !== "open" || tool !== "capture") return
        const r = rect
        if (!r || r.w < 2 || r.h < 2) return
        if (forShare) {
            forShare = false
            const s = monitor.scale
            Share.shareRegion(monitor.name, { x: r.x / s, y: r.y / s, w: r.w / s, h: r.h / s })
            phase = ""
            return
        }
        if (kind === "video") return record(r)
        if (delay > 0) {
            // Live: the countdown, then grim reads the screen as it is then.
            const g = globalRect(r)
            startCountdown(`Screenshot of the ${targetName}`, () => shoot("", `${g.x},${g.y} ${g.w}x${g.h}`, r))
            return
        }
        flyFrom = { x: r.x / monitor.scale, y: r.y / monitor.scale, w: r.w / monitor.scale, h: r.h / monitor.scale }
        phase = "shooting"
        shoot(`${r.w}:${r.h}:${r.x}:${r.y}`, "", r)
    }
    // Print: the whole focused screen, no UI; only the thumbnail card.
    function screenNow() {
        if (phase !== "") return
        const name = Hyprland.focusedMonitor?.name ?? ""
        phase = "shooting"
        flyFrom = null
        cardShown = false
        // After toasts and OSDs have left the screen.
        later(60, () => {
            shotProc.command = ["sh", "-c", script(`grim -o "$5" "$3"`), "sh", "", "", outFile(), output !== "save" ? "1" : "0", name]
            shotProc.size = { w: monitor.width, h: monitor.height }
            shotProc.running = true
        })
    }

    function globalRect(r: var): var {
        const s = monitor.scale
        return { x: Math.round(monitor.x + r.x / s), y: Math.round(monitor.y + r.y / s), w: Math.round(r.w / s), h: Math.round(r.h / s) }
    }
    function outFile(): string {
        const d = new Date(), p = n => String(n).padStart(2, "0")
        const stamp = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}_${p(d.getHours())}-${p(d.getMinutes())}-${p(d.getSeconds())}`
        // "Copy" alone still keeps a temp file, for the card's Annotate / Save as.
        return output === "copy" ? `${runDir}/Screenshot_${stamp}.png` : `${Quickshell.env("HOME")}/Pictures/Screenshots/Screenshot_${stamp}.png`
    }
    // $1 frozen frame, $2 crop (w:h:x:y), $3 out, $4 copy (1/0), $5 grim geometry; `make` writes $3.
    function script(make: string): string {
        return `mkdir -p "$(dirname "$3")"
            ${make} || exit 1
            [ "$4" = 1 ] && wl-copy -t image/png < "$3" >/dev/null 2>&1
            exit 0`
    }
    // crop = from the frozen frame; geometry = a live grim of that area (after a delay).
    function shoot(crop: string, geometry: string, r: var) {
        const make = crop !== "" ? `ffmpeg -v error -y -i "$1" -vf "crop=$2" "$3"` : `grim -g "$5" "$3"`
        shotProc.command = ["sh", "-c", script(make), "sh", freezeFile, crop, outFile(), output !== "save" ? "1" : "0", geometry]
        shotProc.size = { w: r.w, h: r.h }
        shotProc.running = true
    }
    Process {
        id: shotProc
        property var size
        onExited: code => {
            if (code === 0) {
                root.lastShot = command[6]
                root.lastSaved = root.output !== "copy"
                root.lastCopied = command[7] === "1"
                root.lastSize = size
                root.lastTime = Date.now()
                root.cardShown = true
                root.shotTaken()
            }
            // Live shots (Print, after a delay) have no fly-out; the frozen one ends when its motion does.
            if (root.flyFrom === null && root.phase === "shooting") root.phase = ""
        }
    }
    signal shotTaken()
    // The surface calls this when the selection has flown into the corner.
    function flown() { if (phase === "shooting") phase = "" }

    // --- Recording
    function record(r: var) {
        const whole = mode === "screen"
        const opts = { fps: fps, format: format, cursor: cursor, mic: mic, desktopAudio: desktopAudio }
        const g = whole ? null : globalRect(r)
        const out = monitor.name
        const go = () => Recorder.start(out, g, opts)
        if (delay > 0) startCountdown(`Recording ${mode === "region" ? "the region" : mode === "screen" ? "the screen" : targetName}`, go)
        else {
            phase = ""
            // Let the tool's layers unmap before the first frame is read.
            later(120, go)
        }
    }

    // --- Countdown (shown over the live screen; Esc cancels)
    function startCountdown(label: string, fn: var) {
        countdownLabel = label
        pending = fn
        countdown = delay
        phase = "countdown"
        tick.restart()
    }
    Timer {
        id: tick
        interval: Motion.countdownTick
        repeat: true
        running: root.phase === "countdown"
        onTriggered: {
            if (root.countdown > 1) { root.countdown--; return }
            const fn = root.pending
            root.pending = null
            root.countdown = 0
            // The countdown circle leaves the screen first; then the shot / the recorder start.
            root.phase = fn ? "shooting" : ""
            root.flyFrom = null
            if (fn) root.later(120, () => { fn(); if (root.kind === "video") root.phase = "" })
        }
    }

    // --- Colour picker: copy the shown value (lands in the clipboard history as a swatch).
    readonly property string pickText: {
        const c = pickColor, r = Math.round(c.r * 255), g = Math.round(c.g * 255), b = Math.round(c.b * 255)
        if (pickFormat === "rgb") return `rgb(${r} ${g} ${b})`
        if (pickFormat === "hsl") return `hsl(${Math.round(Math.max(0, c.hslHue) * 360)} ${Math.round(c.hslSaturation * 100)}% ${Math.round(c.hslLightness * 100)}%)`
        return hex(c)
    }
    function hex(c: color): string {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0")
        return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase()
    }
    function pick() {
        if (phase !== "open" || tool !== "color") return
        sh(`printf %s "$1" | wl-copy`, [pickText])
        close()
    }

    // --- Card actions (E annotate, S save as, X delete)
    function deleteShot() {
        if (!lastShot) return
        sh(`rm -f "$1"`, [lastShot])
        cardShown = false
        lastShot = ""
    }
    // Save as: copy the shot to another path (the field on the card / in Annotate).
    function saveAs(path: string, done: var) {
        if (!lastShot || path === "") return
        const p = path.replace(/^~/, Quickshell.env("HOME"))
        const src = lastShot
        sh(`mkdir -p "$(dirname "$2")" && cp "$1" "$2"`, [src, p], () => {
            lastShot = p
            lastSaved = true
            if (done) done()
        })
    }

    // Runs a shell snippet with arguments ($1, $2, …), then `done`.
    function sh(script: string, args: var, done: var) {
        const p = runner.createObject(root, { command: ["sh", "-c", script, "sh"].concat(args) })
        p.exited.connect(() => { if (done) done(); p.destroy() })
        p.running = true
    }
    Component {
        id: runner
        Process {}
    }
    function later(ms: int, fn: var) { delay_.createObject(root, { interval: ms, fn: fn }) }
    Component {
        id: delay_
        Timer {
            property var fn
            running: true
            onTriggered: { fn(); destroy() }
        }
    }

    // Annotate: the image being edited ("" = closed). Opening it from the card keeps the card's shot.
    property string annotating: ""
    function annotate(path: string) {
        const f = path !== "" ? path.replace(/^~/, Quickshell.env("HOME")) : lastShot
        if (f === "" || active) return
        Shell.closeAll()
        cardShown = false
        annotating = f
    }

    signal testMark(var m)

    // The thumbnail card waits 6 s (paused while hovered).
    property bool cardHovered: false
    Timer {
        running: root.cardShown && !root.cardHovered && root.annotating === ""
        interval: Motion.shotCardHold
        onTriggered: root.cardShown = false
    }
}
