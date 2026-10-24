pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen backlight through brightnessctl (it goes via logind, so no root needed).
Singleton {
    id: root

    property int percent: 0
    readonly property int step: 5

    function up() { change(`${step}%+`) }
    function down() { change(`${step}%-`) }

    // -n1 keeps the screen from going fully dark. A change asked for while brightnessctl still runs waits
    // for it (only the latest one), so a slider drag doesn't pile up processes.
    property string pending: ""
    function change(arg: string) {
        Osd.show("brightness")
        pending = arg
        kick()
    }
    // A percentage, from the Control Center slider; shown at once, applied in the background.
    function set(p: int) {
        percent = Math.max(1, Math.min(100, p))
        change(percent + "%")
    }
    function kick() {
        if (proc.running || pending === "") return
        proc.command = ["brightnessctl", "-m", "-n1", "set", pending]
        pending = ""
        proc.running = true
    }

    // `brightnessctl -m` prints "device,class,current,percent%,max".
    Process {
        id: proc
        command: ["brightnessctl", "-m"]
        running: true
        onExited: root.kick()
        stdout: SplitParser {
            onRead: line => {
                const p = parseInt(line.split(",")[3])
                if (!isNaN(p)) root.percent = p
            }
        }
    }
}
