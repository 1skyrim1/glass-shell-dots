pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// The greeter's side of logging in (DESIGN.md §3.8 "Login", 26-Login, 27-LoginUsers), for surfaces/Greeter.qml.
// Users come from /etc/passwd (uid 1000–59999 with a login shell), their last login from lastlog2, pictures
// from /var/lib/glass-shell/greeter/faces/<user> (install.sh copies ~/.face there). The one who logged in
// last is picked first. greetd: createSession → answer PAM's prompts with the password → readyToLaunch →
// the log-in motion → launch start-hyprland (greetd ends the greeter and starts the session).
// A failure shakes the pill; pam_faillock's "N seconds left to unlock" becomes the wait countdown.
//
// GLASS_GREETER_TEST=1 runs it inside a normal session: a Guest is added and auth is fake ("wrong" fails,
// anything else "logs in", which only plays the motion and quits).
Singleton {
    id: root

    readonly property bool test: Quickshell.env("GLASS_GREETER_TEST") === "1"
    readonly property string facesDir: "/var/lib/glass-shell/greeter/faces"

    property var users: []    // [{ name, display, face, sub, guest, latest }]
    property int index: 0
    property int lastUsed: 0
    readonly property var user: users[index] ?? null

    property string status: ""   // "" | "checking" | "wrong" | "wait"
    property string note: ""
    property int waitLeft: 0
    property int failures: 0
    property real leaveT: 0      // log-in motion
    property real endT: 0        // power off / reboot: fade to black
    property string password: ""

    function select(i: int) {
        if (status === "checking" || i < 0 || i >= users.length) return
        index = i
        if (status === "wrong") status = ""
    }

    function submit(text: string) {
        if (!user || status === "checking" || status === "wait") return
        password = text
        status = "checking"
        note = ""
        if (test) fakeAuth.restart()
        else Greetd.createSession(user.name)
    }
    Timer {
        id: fakeAuth
        interval: 700
        onTriggered: root.password === "wrong" && !root.user.guest ? root.failed("") : root.ready()
    }

    function failed(message: string) {
        password = ""
        failures++
        // pam_faillock: "The account is locked due to 3 failed logins. (30 seconds left to unlock)"
        const m = /(\d+)\s+(minute|second)s?\s+left/.exec(message)
        if (m) {
            waitLeft = parseInt(m[1]) * (m[2] === "minute" ? 60 : 1)
            status = "wait"
            waitTick.restart()
        } else {
            status = "wrong"
            wrongHold.restart()
        }
    }
    Timer {
        id: wrongHold
        interval: Motion.wrongHold
        onTriggered: if (root.status === "wrong") root.status = ""
    }
    Timer {
        id: waitTick
        interval: 1000
        repeat: true
        onTriggered: if (--root.waitLeft <= 0) { stop(); root.status = "" }
    }
    readonly property string waitNote: status === "wait"
        ? `Too many attempts · wait ${waitLeft >= 60 ? Math.ceil(waitLeft / 60) + " min" : waitLeft + " s"} before trying again` : ""

    // Authenticated: avatar + field sink, the clock flies into the clock pill, the dim lifts; then launch.
    function ready() {
        password = ""
        leaveAnim.restart()
    }
    NumberAnimation {
        id: leaveAnim
        target: root
        property: "leaveT"
        from: 0
        to: 1
        duration: Motion.fixed(Math.round(Motion.login * 0.5))
        easing.type: Motion.easeLarge
        onFinished: {
            if (root.test) Qt.quit()
            else marker.running = true
        }
    }
    // glass-greeter.sh falls back to the text login unless this marker says a session was started.
    Process {
        id: marker
        command: ["touch", Quickshell.env("XDG_RUNTIME_DIR") + "/glass-greeter-launched"]
        onExited: Greetd.launch(["start-hyprland"], ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=Hyprland",
                                                     "XDG_SESSION_DESKTOP=Hyprland"], true)
    }

    Connections {
        target: Greetd
        enabled: !root.test
        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool) {
            if (responseRequired) Greetd.respond(root.password)
            else if (error) root.note = message
        }
        function onReadyToLaunch() { root.ready() }
        function onAuthFailure(message: string) { root.failed(root.note + " " + message) }
        function onError(error: string) { root.failed(error) }
    }

    // Power options: no windows to close here, just fade to black and go.
    function power(kind: string) {
        if (kind === "suspend") {
            if (!test) Quickshell.execDetached(["systemctl", "suspend"])
            return
        }
        endKind = kind
        endAnim.restart()
    }
    property string endKind: ""
    NumberAnimation {
        id: endAnim
        target: root
        property: "endT"
        from: 0
        to: 1
        duration: Motion.fixed(Motion.blackFade)
        onFinished: root.test ? Qt.quit() : Quickshell.execDetached(["systemctl", root.endKind])
    }

    // --- Users
    FileView {
        path: "/etc/passwd"
        onLoaded: {
            const list = []
            for (const line of text().split("\n")) {
                const f = line.split(":")
                const uid = parseInt(f[2])
                if (f.length < 7 || uid < 1000 || uid >= 60000 || /(nologin|false)$/.test(f[6])) continue
                const display = (f[4] ?? "").split(",")[0] || f[0]
                list.push({ name: f[0], display: display, face: root.test ? Quickshell.env("HOME") + "/.face" : `${root.facesDir}/${f[0]}`,
                            sub: "", guest: false, latest: 0 })
            }
            if (root.test) list.push({ name: "guest", display: "Guest", face: "", sub: "no password · files wiped on logout",
                                       guest: true, latest: -1 })
            root.users = list
            lastlog.running = true
        }
    }
    Process {
        id: lastlog
        command: ["lastlog2"]
        stdout: StdioCollector {
            onStreamFinished: {
                const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                const latest = {}
                for (const line of text.split("\n").slice(1)) {
                    // philip  ssh  192.168.178.124  Sat Oct 24 15:14:59 +0200 2026
                    const m = /^(\S+).*\b(\w{3}) (\d+) (\d+):(\d+):\d+ \S+ (\d{4})\s*$/.exec(line)
                    if (m) latest[m[1]] = new Date(parseInt(m[6]), months.indexOf(m[2]), parseInt(m[3]), parseInt(m[4]), parseInt(m[5]))
                }
                const users = root.users.map(u => {
                    if (u.guest) return u
                    const d = latest[u.name]
                    return Object.assign({}, u, { latest: d ? d.getTime() : 0, sub: d ? "last login " + root.when(d) : "never logged in" })
                })
                let best = 0
                users.forEach((u, i) => { if (u.latest > users[best].latest) best = i })
                root.users = users
                root.lastUsed = best
                root.index = best
            }
        }
    }
    function when(d: var): string {
        const today = new Date()
        today.setHours(0, 0, 0, 0)
        const days = Math.round((today - new Date(d.getFullYear(), d.getMonth(), d.getDate())) / 86400000)
        const time = Qt.formatDateTime(d, "HH:mm")
        return days === 0 ? "today, " + time : days === 1 ? "yesterday, " + time : Qt.formatDateTime(d, "d MMM")
    }
}
