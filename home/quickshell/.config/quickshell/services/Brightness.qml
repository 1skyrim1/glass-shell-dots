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

    // -n1 keeps the screen from going fully dark.
    function change(arg: string) {
        Osd.show("brightness")
        proc.command = ["brightnessctl", "-m", "-n1", "set", arg]
        proc.running = true
    }

    // `brightnessctl -m` prints "device,class,current,percent%,max".
    Process {
        id: proc
        command: ["brightnessctl", "-m"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const p = parseInt(line.split(",")[3])
                if (!isNaN(p)) root.percent = p
            }
        }
    }
}
