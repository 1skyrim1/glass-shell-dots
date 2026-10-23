pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Keyboard layout (Hyprland's kb_layout list). `short` is the status pill badge ("DE"), `name` the
// layout's full name for the OSD ("German (Neo 2)"). A switch shows the layout OSD.
Singleton {
    id: root

    property var layouts: []
    property int index: 0
    property string name: ""
    readonly property string short: (layouts[index] ?? "").toUpperCase()

    function next() {
        switcher.running = true
    }

    Process {
        id: switcher
        command: ["hyprctl", "switchxkblayout", "all", "next"]
    }

    // All keyboards share the config's layouts; read them from the main one.
    Process {
        id: devices
        command: ["hyprctl", "devices", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const kbs = JSON.parse(text).keyboards
                const kb = kbs.find(k => k.main) ?? kbs[0]
                if (!kb) return
                root.layouts = kb.layout.split(",")
                root.index = kb.active_layout_index
                if (root.name === "") root.name = kb.active_keymap
            }
        }
    }

    Connections {
        target: Hyprland
        // "activelayout>>keyboard name,layout name"; it fires once per keyboard device, so only a real
        // change counts.
        function onRawEvent(event: HyprlandEvent) {
            if (event.name !== "activelayout") return
            const layout = event.data.slice(event.data.indexOf(",") + 1)
            if (layout === root.name) return
            root.name = layout
            devices.running = true
            Osd.show("layout")
        }
    }
}
