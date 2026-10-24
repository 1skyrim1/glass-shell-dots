pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Keyboard layouts (Hyprland's kb_layout + kb_variant lists). `short` is the status pill badge (the
// variant, else the layout: "DE", "NEO", "BONE"), `name` the active layout's full name for the OSD
// ("German (Neo 2)"), `entries` the layout menu. A switch shows the layout OSD.
Singleton {
    id: root

    property var layouts: []
    property var variants: []
    property int index: 0
    property string name: ""
    // Full names by "layout(variant)", read from the xkb symbol files.
    property var names: ({})
    // [{ code: "NEO", name: "German (Neo 2)" }, …] in kb_layout order.
    readonly property var entries: layouts.map((l, i) => {
        const v = variants[i] ?? ""
        return { code: (v || l).toUpperCase(), name: names[`${l}(${v})`] ?? l }
    })
    readonly property string short: entries[index]?.code ?? ""

    function next() { switcher.exec(["hyprctl", "switchxkblayout", "all", "next"]) }
    function select(i: int) { switcher.exec(["hyprctl", "switchxkblayout", "all", String(i)]) }

    Process { id: switcher }

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
                root.variants = kb.variant.split(",")
                root.index = kb.active_layout_index
                if (Object.keys(root.names).length === 0) symbols.load()
                if (root.name === "") root.name = kb.active_keymap
            }
        }
    }

    // Each layout's symbol file has a block per variant with its name[Group1]; the block marked
    // `default` (usually "basic", the keyword may sit on the line above) is the plain layout.
    // Bone isn't in base.lst, so the names come from there.
    Process {
        id: symbols
        function load() {
            const files = [...new Set(root.layouts)].filter(l => /^[a-z0-9_]+$/.test(l))
            command = ["sh", "-c", 'for l; do echo "@@ $l"; grep -E "^default|xkb_symbols|name\\[Group1\\]" "/usr/share/X11/xkb/symbols/$l"; done',
                       "sh", ...files]
            running = true
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const names = {}, defaults = {}
                let file = "", block = "", isDefault = false
                for (const line of text.split("\n")) {
                    let m
                    if (line.startsWith("@@ ")) {
                        file = line.slice(3)
                    } else if ((m = line.match(/xkb_symbols\s+"([^"]+)"/))) {
                        block = m[1]
                        if (isDefault || /^default\b/.test(line)) defaults[file] = block
                        isDefault = false
                    } else if (/^default\b/.test(line)) {
                        isDefault = true
                    } else if ((m = line.match(/name\[Group1\]\s*=\s*"([^"]+)"/))) {
                        const key = `${file}(${block})`
                        if (!(key in names)) names[key] = m[1]
                    }
                }
                for (const f in defaults) names[`${f}()`] = names[`${f}(${defaults[f]})`]
                root.names = names
            }
        }
    }

    Connections {
        target: Hyprland
        // "activelayout>>keyboard name,layout name"; it fires once per keyboard device, so only a real
        // change counts. Virtual keyboards (wtype typing for the launcher) bring their own keymap: ignored.
        function onRawEvent(event: HyprlandEvent) {
            if (event.name !== "activelayout" || event.data.startsWith("hl-virtual-keyboard")) return
            const layout = event.data.slice(event.data.indexOf(",") + 1)
            if (layout === root.name) return
            root.name = layout
            devices.running = true
            Osd.show("layout")
        }
    }
}
