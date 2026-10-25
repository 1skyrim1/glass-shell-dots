pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Polkit

// The polkit agent (DESIGN.md §3.8 "Polkit", 31-Polkit, 30 "Polkit: wrong password"); surfaces/AuthDialog.qml
// draws it. Quickshell's flow restarts itself after a wrong password; this counts the tries and gives up
// after the 3rd (cancel + a "denied" notification). Only one request is ever active (polkit queues the rest).
// Locking cancels it (§4). Replaces hyprpolkitagent: only one agent can be registered per session.
Singleton {
    id: root

    readonly property AuthFlow flow: agent.flow
    readonly property bool active: agent.isActive && flow !== null
    readonly property int maxTries: 3
    property int failures: 0
    property string status: ""      // "" | "checking" | "wrong"
    property real requestedAt: 0
    // pkexec names the program and its PID; other callers (D-Bus services) don't tell the agent who they are.
    property string program: ""
    property int pid: 0
    property bool wheel: false

    function submit(text: string) {
        if (!flow || status === "checking") return
        status = "checking"
        flow.submit(text)
    }
    function cancel() { if (flow) flow.cancelAuthenticationRequest() }

    PolkitAgent { id: agent }

    // Super shortcuts are ignored while the prompt is up (§4): conf/binds.lua's bind-less "prompt" submap.
    onActiveChanged: Hyprland.dispatch(active ? `hl.dsp.submap("prompt")` : `hl.dsp.submap("reset")`)

    onFlowChanged: {
        failures = 0
        status = ""
        program = ""
        pid = 0
        if (!flow) return
        requestedAt = Date.now()
        if (flow.actionId === "org.freedesktop.policykit.exec") caller.running = true
        groups.running = true
        flow.authenticationFailed.connect(() => root.failedOnce())
        flow.authenticationSucceeded.connect(() => root.status = "")
    }
    // The flow asks again by itself after a failure (isResponseRequired goes true once more).
    function failedOnce() {
        failures++
        status = "wrong"
        if (failures < maxTries) return
        const what = flow?.message ?? ""
        cancel()
        Notifs.make({
            app: "Authentication",
            body: "<b>Request denied</b> · " + what.replace(/&/g, "&amp;").replace(/</g, "&lt;")
                  + ` (${maxTries} wrong passwords)`,
            icon: "shield",
            colors: { fill: Theme.errorContainer, stroke: Theme.textOnError }
        })
    }

    Process {
        id: caller
        // "<pid> <program as a full path>" of the newest pkexec.
        command: ["sh", "-c", 'set -- $(pgrep -n -a pkexec); pid=$1; shift 2; '
                  + 'while [ "${1#--}" != "$1" ]; do shift; done; [ -n "$1" ] || exit; p="$1"; '
                  + 'case "$p" in /*) ;; *) for d in $(echo "$PATH" | tr : " "); do [ -x "$d/$p" ] && p="$d/$p" && break; done ;; esac; '
                  + 'echo "$pid $p"']
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/^(\d+) (.+)$/)
                if (!m) return
                root.pid = parseInt(m[1])
                root.program = m[2]
            }
        }
    }
    // "· wheel" next to the user when they're an administrator.
    Process {
        id: groups
        command: ["id", "-nG"]
        stdout: StdioCollector { onStreamFinished: root.wheel = text.split(/\s+/).includes("wheel") }
    }
}
