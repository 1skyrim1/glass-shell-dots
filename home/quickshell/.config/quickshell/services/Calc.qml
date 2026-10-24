pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Calculator mode (= prefix, 14-Modes): qalc evaluates as you type (~120 ms after the last key, ~90 ms
// per run). Integer results also show hex and binary. "16 GiB in MB" works like "… to MB".
Singleton {
    id: root

    property string expr: ""
    property string result: ""      // "" = nothing to show (empty or not maths)
    property string resultFor: ""   // the expression `result` belongs to (qalc answers ~100 ms later)
    property var whenReady: null    // copy() waiting for that answer
    readonly property bool integer: /^-?\d+$/.test(plain(result)) && Number.isSafeInteger(Number(plain(result)))
    readonly property string hex: integer ? "0x" + Number(plain(result)).toString(16).toUpperCase() : ""
    readonly property string bin: integer ? Number(plain(result)).toString(2) : ""

    // qalc prints a real minus sign and thin spaces; copy plain ASCII.
    function plain(s: string): string { return s.replace(/\u2212/g, "-").replace(/[\u2009\u202f]/g, "") }

    function evaluate(text: string) {
        expr = text
        if (text.trim() === "") result = ""
        debounce.restart()
    }

    // Copies the result of what's typed now (waiting for qalc if it's still working), then `done`.
    function copy(done: var) {
        if (resultFor !== expr.trim() || debounce.running) {
            whenReady = () => copy(done)
            if (debounce.running) { debounce.stop(); debounce.triggered() }
            return
        }
        whenReady = null
        if (result === "") return
        Quickshell.execDetached(["wl-copy", "--", plain(result)])
        LauncherState.pushCalc(expr.trim(), result)
        if (done) done()
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: {
            const e = root.expr.trim()
            // Words alone aren't maths (qalc would read them as units).
            if (!/\d|\bpi\b|\be\b/.test(e)) { root.result = ""; root.resultFor = e; root.answered(); return }
            qalc.running = false
            qalc.expr = e
            qalc.command = ["qalc", "-t", "-s", "update_exchange_rates 0", e.replace(/\s+in\s+(?=[A-Za-z$€£¥]+$)/, " to ")]
            qalc.running = true
        }
    }

    function answered() { if (whenReady) whenReady() }

    Process {
        id: qalc
        property string expr
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim().split("\n").pop() ?? ""
                root.result = /error|warning/i.test(out) ? "" : out
                root.resultFor = qalc.expr
                root.answered()
            }
        }
    }
}
