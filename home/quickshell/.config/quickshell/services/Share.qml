pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Screen sharing (DESIGN.md §3.7, 25-SharePicker). xdg-desktop-portal-hyprland runs scripts/share-picker.sh
// when an app asks to share the screen; the script calls `share pick` and waits on a FIFO for the answer.
// The picker (surfaces/SharePicker.qml) offers Screen / Window / Region; Region hands over to the capture tool's
// region selection and comes back with the rectangle. While a share runs (Hyprland's `screencast` event) a
// green pill splits off the clock; its Stop ends the stream by destroying xdph's PipeWire node.
Singleton {
    id: root

    // --- The open request ("" fifo = no picker)
    property string fifo: ""
    readonly property bool asking: fifo !== ""
    property string app: ""            // "Discord", from the portal's app id or the focused window
    property string appClass: ""       // icon lookup
    property bool tokenAllowed: false  // the app asked to be remembered (xdph --allow-token)
    property bool remember: false
    property string tab: "window"      // screen | window | region
    property int selected: 0
    // [{ id (xdph handle), cls, title, address, toplevel (HyprlandToplevel), workspace }]
    property var windows: []
    readonly property var screens: Quickshell.screens

    // --- While sharing
    property bool sharing: false
    property string label: ""          // "Hollow Knight", "eDP-1", "a region"
    property string pickedLabel: ""

    // xdph's list: id[HC>]class[HT>]title[HE>]address[HA>]…  (address in decimal).
    function pick(fifoPath: string, list: string, token: string, appId: string) {
        if (asking) answer("")   // a newer request replaces an old one
        Capture.close()
        Shell.closeAll()
        const tops = Hyprland.toplevels.values
        windows = list.split("[HA>]").filter(e => e.includes("[HC>]")).map(e => {
            const id = e.slice(0, e.indexOf("[HC>]"))
            const cls = e.slice(e.indexOf("[HC>]") + 5, e.indexOf("[HT>]"))
            const title = e.slice(e.indexOf("[HT>]") + 5, e.indexOf("[HE>]"))
            const addr = Number(e.slice(e.indexOf("[HE>]") + 5)).toString(16)
            const t = tops.find(t => t.address === addr) ?? null
            return { id: id, cls: cls, title: title, address: addr, toplevel: t, workspace: t?.workspace?.name ?? "" }
        }).filter(w => w.toplevel === null || !w.toplevel.workspace?.name?.startsWith("special:"))
        pickedLabel = ""
        tokenAllowed = token === "1"
        remember = false
        // App name: the portal's app id ("com.discordapp.Discord" → "Discord"), else the focused window's class.
        const focused = Hyprland.activeToplevel?.lastIpcObject?.class ?? ""
        const raw = appId !== "" ? appId.split(".").pop() : focused
        appClass = appId !== "" ? appId : focused
        app = raw !== "" ? raw.charAt(0).toUpperCase() + raw.slice(1) : "An app"
        tab = windows.length > 0 ? "window" : "screen"
        selected = 0
        fifo = fifoPath
    }

    readonly property int count: tab === "window" ? windows.length : tab === "screen" ? screens.length : 0
    function move(step: int) { if (count > 0) selected = (selected + step + count) % count }
    function setTab(t: string) { tab = t; selected = 0 }
    function nextTab() { setTab(({ screen: "window", window: "region", region: "screen" })[tab]) }

    // Enter / Share.
    function share() {
        if (!asking) return
        const flags = remember && tokenAllowed ? "r" : ""
        if (tab === "region") {
            // The capture tool picks the rectangle, then comes back through shareRegion().
            const f = fifo
            pendingFlags = flags
            pendingFifo = f
            fifo = ""
            Capture.openForShare()
            return
        }
        if (tab === "screen") {
            const s = screens[selected]
            pickedLabel = s?.name ?? "your screen"
            answer(`[SELECTION]${flags}/screen:${s?.name ?? ""}`)
        } else {
            const w = windows[selected]
            if (!w) return
            pickedLabel = w.title || w.cls
            answer(`[SELECTION]${flags}/window:${w.id}`)
        }
    }
    function cancel() { if (asking) answer("") }

    // Region: the capture tool hands back the rectangle (output name, logical px on it).
    property string pendingFifo: ""
    property string pendingFlags: ""
    function shareRegion(output: string, r: var) {
        if (pendingFifo === "") return
        fifo = pendingFifo
        pendingFifo = ""
        pickedLabel = "a region"
        answer(`[SELECTION]${pendingFlags}/region:${output}@${Math.round(r.x)},${Math.round(r.y)},${Math.round(r.w)},${Math.round(r.h)}`)
    }
    function regionCancelled() {
        if (pendingFifo === "") return
        fifo = pendingFifo
        pendingFifo = ""
        answer("")
    }

    function answer(line: string) {
        const f = fifo
        fifo = ""
        windows = []
        // The script waits on the FIFO; if it's gone (timed out), don't hang on the write.
        const p = runner.createObject(root, { command: ["timeout", "5", "sh", "-c", `printf '%s\\n' "$2" > "$1"`, "sh", f, line] })
        p.exited.connect(() => p.destroy())
        p.running = true
    }

    // --- Sharing state: Hyprland's `screencast` event is "1,<owner>" when a share starts, "0,…" when it ends.
    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent) {
            if (event.name !== "screencast") return
            const on = event.data.split(",")[0] === "1"
            // xdph may stop and start the capture while the stream settles, so the picked label stays until the
            // next pick (a share restored without the picker says "your screen").
            if (on) root.label = root.pickedLabel !== "" ? root.pickedLabel : "your screen"
            root.sharing = on
        }
    }

    // Stop: destroy xdph's stream nodes (the app sees the share end); restarting the portal is the fallback.
    function stop() {
        const p = runner.createObject(root, { command: ["sh", "-c", `
            ids=$(pw-cli ls Node 2>/dev/null | awk '/^[[:space:]]*id [0-9]+,/ { id = $2; sub(",", "", id) }
                                                    /node.name = "xdg-desktop-portal-hyprland"/ { print id }')
            [ -n "$ids" ] || exit 1
            for id in $ids; do pw-cli destroy "$id" >/dev/null 2>&1 || exit 1; done`] })
        p.exited.connect(code => {
            p.destroy()
            if (code !== 0) restart.running = true
            else root.sharing = false
        })
        p.running = true
    }
    Process {
        id: restart
        command: ["systemctl", "--user", "restart", "xdg-desktop-portal-hyprland"]
        onExited: root.sharing = false
    }

    Component {
        id: runner
        Process {}
    }
}
