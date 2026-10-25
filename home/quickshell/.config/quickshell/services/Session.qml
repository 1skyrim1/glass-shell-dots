pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// Lock, unlock and the power actions (DESIGN.md §3.8, §4; 06-MotionSession).
//
// Lock:   phase "" → "locking": panels close, password prompts are cancelled, the pills float up (barT 1 → 0),
//         grim freezes every screen into $XDG_RUNTIME_DIR, then the session lock goes up (surfaces/Lock.qml) and
//         plays its entrance (lockT 0 → 1) → "locked".
// Unlock: PAM says yes → "unlocking": avatar + field sink, the clock shrinks into its pill, the blur clears
//         (leaveT 0 → 1) → the lock is released and the pills drop back in (barT 0 → 1) → "".
// The lock screen runs as the user, so pam_faillock can't count its failures; it adds its own wait instead
// (every 3rd wrong password: Motion.lockWait seconds).
//
// `preview` shows the same lock screen on an ordinary Overlay layer with fake auth ("wrong" fails, anything
// else unlocks), for screenshots without really locking the session (`qs ipc call lock preview`).
//
// If qs dies while locked, Hyprland keeps the session locked (it shows a "lockdead" screen). Recover from a TTY
// (Ctrl+Alt+F2): `HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/$UID/hypr) hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`;
// misc.allow_session_lock_restore (Hyprland's conf/session.lua) lets the new qs take the lock over, then unlock normally.
Singleton {
    id: root

    property string phase: ""          // "" | "locking" | "locked" | "unlocking"
    property bool preview: false
    property bool surfaceUp: false     // the session lock (or the preview layer) is mapped
    readonly property bool locked: phase !== ""
    property real barT: 1              // the bar's pills: 0 = floated away, 1 = in place (Bar.qml staggers them)
    property real lockT: 0             // lock screen entrance
    property real leaveT: 0            // lock screen exit (unlock)
    property int shotId: 0             // bumps with every new frozen frame, so Image reloads it
    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") + "/glass-shell"
    function shotOf(screenName: string): string { return `file://${runDir}/lock-${screenName}.ppm?${shotId}` }

    // --- Password state shared by every screen's lock surface
    property string status: ""         // "" | "checking" | "wrong" | "wait"
    property int failures: 0
    property int waitLeft: 0           // s
    property string password: ""
    readonly property string user: Quickshell.env("USER")

    function lock(instant: bool) {
        if (phase !== "") return
        Shell.lock()
        Polkit.cancel()
        if (Capture.phase !== "") Capture.close()
        Capture.annotating = ""   // the Annotate editor doesn't survive a lock either
        phase = "locking"
        status = ""
        lockT = 0
        leaveT = 0
        barAnim.stop()
        if (instant || Motion.reduced) {
            barT = 0
            shoot()
        } else {
            barAnim.to = 0
            barAnim.duration = Motion.preLock
            barAnim.easing.type = Motion.easeClose
            barAnim.restart()
        }
    }
    function startPreview() {
        if (phase !== "") return
        preview = true
        lock(false)
    }

    // Freeze every screen (grim, PPM is fastest), then map the lock. A watchdog maps it anyway if grim hangs.
    function shoot() {
        const outs = Quickshell.screens.map(s => s.name)
        grim.command = ["sh", "-c", 'd="$1"; shift; mkdir -p "$d"; for o; do grim -t ppm -o "$o" "$d/lock-$o.ppm"; done',
                        "sh", runDir, ...outs]
        grim.running = true
        grimWatchdog.restart()
    }
    Process {
        id: grim
        onExited: root.raise()
    }
    Timer {
        id: grimWatchdog
        interval: 1500
        onTriggered: root.raise()
    }
    function raise() {
        grimWatchdog.stop()
        if (phase !== "locking" || surfaceUp) return
        shotId++
        surfaceUp = true
        tAnim.property = "lockT"
        tAnim.duration = Motion.fixed(Motion.lock)
        tAnim.easing.type = Motion.easeLarge
        tAnim.restart()
    }

    function unlock() {
        if (phase !== "locked" && phase !== "locking") return
        phase = "unlocking"
        status = ""
        password = ""
        tAnim.stop()
        lockT = 1
        tAnim.property = "leaveT"
        // The lock layer's part of the unlock (06-MotionSession 80–88 %); the pills' drop-in is the rest.
        tAnim.duration = Motion.fixed(Math.round(Motion.unlock * 0.62))
        tAnim.easing.type = Motion.easeLarge
        tAnim.restart()
    }

    NumberAnimation {
        id: tAnim
        target: root
        property: "lockT"
        from: 0
        to: 1
        onFinished: {
            if (root.phase === "locking") {
                root.phase = "locked"
            } else if (root.phase === "unlocking") {
                root.surfaceUp = false
                root.preview = false
                root.phase = ""
                root.failures = 0
                Shell.locked = false
                root.arrive(Motion.arrive)
                cleanup.running = true
            }
        }
    }
    Process {
        id: cleanup
        command: ["sh", "-c", 'rm -f "$1"/lock-*.ppm', "sh", root.runDir]
    }

    NumberAnimation {
        id: barAnim
        target: root
        property: "barT"
        onFinished: if (root.phase === "locking" && root.barT === 0) root.shoot()
    }
    // The pills drop back in (after unlock, and after log in: GLASS_SHELL_LOGIN, set by Hyprland's conf/session.lua).
    function arrive(ms: int) {
        barAnim.stop()
        barAnim.to = 1
        barAnim.duration = Motion.fixed(ms)
        barAnim.easing.type = Easing.OutCubic
        barAnim.restart()
    }
    Component.onCompleted: {
        if (Quickshell.env("GLASS_SHELL_LOGIN") === "1") {
            barT = 0
            loginArrive.start()
        }
    }
    // Wait for the wallpaper and pills to be on screen before they drop in.
    Timer {
        id: loginArrive
        interval: 250
        onTriggered: root.arrive(Math.round(Motion.login * 0.5))
    }

    // --- Authentication
    function submit(text: string) {
        if (phase !== "locked" && phase !== "locking") return
        if (status === "checking" || status === "wait") return
        if (text === "") return
        password = text
        status = "checking"
        if (preview) {
            fakeAuth.restart()
        } else {
            pam.config = pamFile.exists ? "glass-shell-lock" : "login"
            if (!pam.start()) failed()
        }
    }
    Timer {
        id: fakeAuth
        interval: 700
        onTriggered: root.password === "wrong" ? root.failed() : root.succeeded()
    }
    function succeeded() {
        password = ""
        unlock()
    }
    function failed() {
        password = ""
        failures++
        status = "wrong"
        wrongHold.restart()
    }
    // The red pill holds, then clears; every 3rd failure turns into a wait.
    Timer {
        id: wrongHold
        interval: Motion.wrongHold
        onTriggered: {
            if (root.status !== "wrong") return
            if (root.failures % 3 === 0) {
                root.waitLeft = Motion.lockWait
                root.status = "wait"
                waitTick.restart()
            } else {
                root.status = ""
            }
        }
    }
    Timer {
        id: waitTick
        interval: 1000
        repeat: true
        onTriggered: {
            root.waitLeft--
            if (root.waitLeft <= 0) {
                stop()
                root.status = ""
            }
        }
    }

    PamContext {
        id: pam
        onPamMessage: if (responseRequired) respond(root.password)
        onCompleted: result => result === PamResult.Success ? root.succeeded() : root.failed()
        onError: root.failed()
    }
    // /etc/pam.d/glass-shell-lock (system/, installed by install.sh). Until it exists, "login" does the same.
    FileView {
        id: pamFile
        readonly property bool exists: loaded
        path: "/etc/pam.d/glass-shell-lock"
        printErrors: false
    }

    // --- Power actions
    // "poweroff" | "reboot" | "logout" while the shutting-down screen is up (surfaces/Ending.qml): every window
    // gets a graceful close, the screen names the first one still open, and once none are left the action runs.
    // An app may ask something first ("really close?", save changes) that the black screen hides: Esc cancels to
    // go and answer it, Enter closes the holdouts anyway (SIGTERM, SIGKILL 3 s later). From the lock screen
    // nobody can answer, so that happens by itself after 5 s.
    property string ending: ""
    property string blocker: ""   // the app holding things up
    property var blockerPids: []   // every window's process still open
    property real endT: 0          // fade to black
    function suspend() { run(["systemctl", "suspend"]) }
    property bool dryRun: false    // `qs ipc call session preview <kind>`: the screen only, nothing closes or runs
    function end(kind: string) {
        if (ending !== "") return
        Shell.closeAll()
        dryRun = false
        ending = kind
        blocker = ""
        blockerPids = []
        endAnim.restart()
        if (locked) autoForce.restart()
    }
    function forceEnd() {
        if (ending === "" || dryRun || blockerPids.length === 0) return
        const pids = blockerPids.map(String)
        run(["kill", "-TERM", ...pids])
        killLater.pids = pids
        killLater.restart()
    }
    Timer {
        id: killLater
        property var pids: []
        interval: 3000
        onTriggered: if (root.ending !== "") root.run(["kill", "-KILL", ...pids])
    }
    Timer {
        id: autoForce
        interval: 5000
        onTriggered: root.forceEnd()
    }
    function previewEnd(kind: string) {
        end(kind)
        dryRun = true
    }
    function cancelEnd() {
        dryRun = false
        endAnim.stop()
        endPoll.stop()
        autoForce.stop()
        killLater.stop()
        ending = ""
        endT = 0
    }
    NumberAnimation {
        id: endAnim
        target: root
        property: "endT"
        from: 0
        to: 1
        duration: Motion.fixed(Motion.blackFade)
        easing.type: Easing.InOutCubic
        onFinished: {
            if (root.dryRun) {
                root.blocker = "Firefox"
                return
            }
            closer.running = true
            endPoll.restart()
        }
    }
    // Ask every window to close (like clicking its ×).
    Process {
        id: closer
        command: ["sh", "-c", "hyprctl clients -j | grep -o '\"address\": *\"0x[0-9a-f]*\"' | grep -o '0x[0-9a-f]*' "
                  + "| while read -r a; do hyprctl dispatch \"hl.dsp.window.close({ window = \\\"address:$a\\\" })\" >/dev/null; done"]
    }
    Timer {
        id: endPoll
        interval: 500
        repeat: true
        onTriggered: clients.running = true
    }
    Process {
        id: clients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.ending === "") return
                let list = []
                try { list = JSON.parse(text) } catch (e) {}
                if (list.length === 0) {
                    endPoll.stop()
                    root.finish()
                    return
                }
                root.blockerPids = [...new Set(list.map(c => c.pid).filter(p => p > 0))]
                const c = list[0]
                root.blocker = DesktopEntries.heuristicLookup(c.class)?.name || c.class || c.title
            }
        }
    }
    function finish() {
        const kind = ending
        if (kind === "logout") run(["hyprctl", "dispatch", "hl.dsp.exit()"])
        else run(["systemctl", kind])
    }
    function run(cmd: var) { Quickshell.execDetached(cmd) }

    // --- Lock before sleep, and on `loginctl lock-session`
    // A delay inhibitor holds the suspend back until the lock is up; logind's PrepareForSleep starts the lock.
    Process {
        id: inhibitor
        running: true
        // Holds until released, or until this qs is gone (a killed qs doesn't take its children along).
        command: ["sh", "-c", 'qs=$PPID; exec systemd-inhibit --what=sleep --mode=delay --who="Glass Shell" '
                  + '--why="Lock the screen before sleeping" sh -c "while kill -0 $qs 2>/dev/null; do sleep 2; done"']
    }
    readonly property bool lockShown: phase === "locked" || (phase === "locking" && surfaceUp)
    property bool sleeping: false
    onLockShownChanged: if (lockShown && sleeping) releaseSleep.restart()
    // A moment for the lock's first frame to reach the screen.
    Timer {
        id: releaseSleep
        interval: 300
        onTriggered: inhibitor.running = false
    }
    Process {
        id: logind
        running: true
        command: ["sh", "-c", 'p=$(gdbus call --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1 '
                  + '--method org.freedesktop.login1.Manager.GetSession "$XDG_SESSION_ID" 2>/dev/null | grep -o "/[^\']*"); '
                  + 'echo "session $p"; qs=$PPID; gdbus monitor --system --dest org.freedesktop.login1 & m=$!; '
                  + 'while kill -0 $qs 2>/dev/null; do sleep 2; done; kill $m']
        property string sessionPath: ""
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("session ")) {
                    logind.sessionPath = line.slice(8)
                } else if (line.includes(".Manager.PrepareForSleep (true")) {
                    root.sleeping = true
                    if (root.lockShown) releaseSleep.restart()
                    else root.lock(true)
                } else if (line.includes(".Manager.PrepareForSleep (false")) {
                    root.sleeping = false
                    inhibitor.running = true
                } else if (line.includes(".Session.Lock ()") && logind.sessionPath !== ""
                           && line.startsWith(logind.sessionPath + ":")) {
                    root.lock(false)
                }
            }
        }
    }
}
