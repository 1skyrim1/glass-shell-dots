pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording (DESIGN.md §3.7, 22-CaptureWindow, 24-CaptureExtras) with gpu-screen-recorder: it reads the
// monitor straight from KMS and encodes with VAAPI (h264 on this Intel GPU), so recording costs little CPU and
// needs no portal. A region or window is recorded as a fixed rectangle (`-region`, logical px). SIGINT ends the
// recording cleanly. Clips go to ~/Videos/Captures; afterwards ffprobe/ffmpeg give the duration, size and a
// thumbnail for the "Recording saved" card, and the trim strip's frames. Trim saves `<name>_trim.<ext>` next to the
// original (exact cut, VAAPI re-encode); the original is kept.
// While recording, Notifs holds toasts back and OSDs stay hidden, so neither lands in the clip (§4).
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Videos/Captures"
    readonly property string cache: Quickshell.env("XDG_RUNTIME_DIR") + "/glass-shell/recording"

    property bool recording: false
    property string file: ""
    property real since: 0
    property int seconds: 0
    readonly property string recordingTime: clock(seconds)
    function clock(s: int): string {
        const mm = Math.floor(s / 60) % 60, ss = s % 60, hh = Math.floor(s / 3600)
        return (hh > 0 ? hh + ":" : "") + String(mm).padStart(2, "0") + ":" + String(ss).padStart(2, "0")
    }

    // The last clip, for the saved card: { file, name, duration (s), size (bytes), thumb }; null = no card.
    property var saved: null
    property bool cardShown: false
    // Trim strip: frames (image paths), start / end in seconds; "" = closed, "open", "saving", "done".
    property string trim: ""
    property var frames: []
    property real trimStart: 0
    property real trimEnd: 0

    // output = monitor name; rect = {x, y, w, h} in global logical px, or null for the whole monitor.
    // opts = { fps, format ("mp4" | "mkv"), cursor, mic, desktopAudio }.
    function start(output: string, rect: var, opts: var) {
        if (recording || proc.running) return
        const d = new Date(), p = n => String(n).padStart(2, "0")
        const stamp = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}_${p(d.getHours())}-${p(d.getMinutes())}-${p(d.getSeconds())}`
        file = `${dir}/Recording_${stamp}.${opts.format}`
        const cmd = ["gpu-screen-recorder"]
        if (rect) cmd.push("-w", "region", "-region", `${Math.round(rect.w)}x${Math.round(rect.h)}+${Math.round(rect.x)}+${Math.round(rect.y)}`)
        else cmd.push("-w", output)
        cmd.push("-f", String(opts.fps), "-c", opts.format, "-k", "h264", "-cursor", opts.cursor ? "yes" : "no")
        // Desktop audio and mic mixed into one track; aac so the mp4 plays everywhere (the default is opus).
        const audio = [opts.desktopAudio ? "default_output" : "", opts.mic ? "default_input" : ""].filter(a => a).join("|")
        if (audio) cmd.push("-a", audio, "-ac", "aac")
        cmd.push("-o", file)
        // `exec`, so the process Quickshell signals is the recorder itself.
        proc.command = ["sh", "-c", `mkdir -p "$1" && shift && exec "$@"`, "sh", dir].concat(cmd)
        proc.running = true
        closeCard()
        since = Date.now()
        seconds = 0
        recording = true
    }
    function stop() { if (proc.running) proc.signal(2) }
    function toggle() { recording ? stop() : Capture.open("", "video") }

    Timer {
        running: root.recording
        repeat: true
        interval: 1000
        onTriggered: root.seconds = Math.round((Date.now() - root.since) / 1000)
    }

    Process {
        id: proc
        stderr: StdioCollector { id: errors }
        onExited: code => {
            root.recording = false
            // A clean stop exits 0; anything else is an error worth showing (e.g. no VAAPI, bad region).
            if (code !== 0) {
                const tail = errors.text.trim().split("\n").slice(-2).join(" ")
                Notifs.make({ app: "Recording failed", body: tail || `gpu-screen-recorder exited with ${code}`,
                              icon: "video", colors: { fill: Theme.errorContainer, stroke: Theme.textOnError } })
                return
            }
            probe.file = root.file
            probe.command = ["sh", "-c", `
                f=$1; t=$2
                mkdir -p "$(dirname "$t")"
                ffmpeg -v error -y -ss 1 -i "$f" -frames:v 1 -vf scale=-2:216 "$t" 2>/dev/null ||
                    ffmpeg -v error -y -i "$f" -frames:v 1 -vf scale=-2:216 "$t"
                ffprobe -v error -show_entries format=duration -of csv=p=0 "$f"
                stat -c %s "$f"`, "sh", root.file, `${root.cache}/thumb-${Date.now()}.jpg`]
            probe.running = true
        }
    }

    // Duration, size and thumbnail, then the saved card drops out of the pill as it merges back.
    Process {
        id: probe
        property string file
        stdout: StdioCollector {
            onStreamFinished: {
                const [duration, size] = text.trim().split("\n")
                const thumb = probe.command[probe.command.length - 1]
                // Stopped before the first frame: an empty, unplayable file. Drop it, no card.
                if (!(parseFloat(duration) > 0)) {
                    root.sh(`rm -f "$1"`, [probe.file])
                    return
                }
                root.saved = { file: probe.file, name: probe.file.split("/").pop(), duration: parseFloat(duration) || 0,
                               size: parseInt(size) || 0, thumb: thumb }
                root.cardShown = true
            }
        }
    }

    function closeCard() {
        cardShown = false
        trim = ""
    }

    // --- Card actions
    function copy() {
        if (!saved) return
        sh(`printf 'file://%s\\n' "$1" | wl-copy -t text/uri-list`, [saved.file])
    }
    // Nautilus (or any FileManager1) opens the folder with the clip selected; plain xdg-open otherwise.
    function openFolder() {
        if (!saved) return
        sh(`gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 \
              --method org.freedesktop.FileManager1.ShowItems "['file://$1']" "" >/dev/null 2>&1 || xdg-open "$(dirname "$1")"`,
           [saved.file])
        closeCard()
    }

    // --- Trim: about 8 frames across the clip, both ends start at the clip's ends.
    function openTrim() {
        if (!saved || trim !== "") return
        trim = "open"
        trimStart = 0
        trimEnd = saved.duration
        frames = []
        const n = 8, out = `${cache}/strip-${Date.now()}`
        filmstrip.out = out
        filmstrip.command = ["sh", "-c", `mkdir -p "$3" && ffmpeg -v error -y -i "$1" -vf "fps=$2,scale=-2:80" -frames:v 8 "$3/%d.jpg"`,
                             "sh", saved.file, `${n}/${Math.max(saved.duration, 0.1)}`, out]
        filmstrip.running = true
    }
    Process {
        id: filmstrip
        property string out
        onExited: root.frames = [1, 2, 3, 4, 5, 6, 7, 8].map(i => `${out}/${i}.jpg`)
    }
    // `,` / `.` move the start / end by a step; the other key of the pair (with Shift) moves backwards.
    function nudge(which: string, step: real) {
        if (!saved) return
        if (which === "start") trimStart = Math.max(0, Math.min(trimEnd - 0.5, trimStart + step))
        else trimEnd = Math.min(saved.duration, Math.max(trimStart + 0.5, trimEnd + step))
    }
    function saveTrim() {
        if (!saved || trim !== "open") return
        trim = "saving"
        const out = saved.file.replace(/(\.[^.]+)$/, "_trim$1")
        trimProc.command = ["sh", "-c", `
            ffmpeg -v error -y -vaapi_device /dev/dri/renderD128 -ss "$2" -to "$3" -i "$1" \
                -vf 'format=nv12,hwupload' -c:v h264_vaapi -c:a aac "$4"`,
            "sh", saved.file, trimStart.toFixed(2), trimEnd.toFixed(2), out]
        trimProc.running = true
    }
    Process {
        id: trimProc
        onExited: code => {
            root.trim = code === 0 ? "done" : "open"
            if (code === 0) cardTimer.restart()
        }
    }

    // The card stays 10 s (it has actions, like a notification), longer while the trim strip is open.
    Timer {
        id: cardTimer
        running: root.cardShown && (root.trim === "" || root.trim === "done") && !root.cardHovered
        interval: Motion.toastLong
        onTriggered: root.closeCard()
    }
    property bool cardHovered: false

    // Runs a shell snippet with arguments ($1, $2, …).
    function sh(script: string, args: var) {
        const p = runner.createObject(root, { command: ["sh", "-c", script, "sh"].concat(args) })
        p.exited.connect(() => p.destroy())
        p.running = true
    }
    Component {
        id: runner
        Process {}
    }
}
