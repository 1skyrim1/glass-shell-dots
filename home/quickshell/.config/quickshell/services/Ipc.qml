import QtQuick
import Quickshell
import Quickshell.Io

// One IpcHandler per surface; hyprland.lua binds call `qs ipc call <target> <function>` (DESIGN.md §6).
// List everything with `qs ipc show`. Surfaces that don't exist yet only track state in Shell.
Item {
    IpcHandler {
        target: "launcher"
        function toggle(): void { Shell.toggle("launcher") }
        // Open straight into a mode: "clipboard" (Super+V), "emoji" (Super+.), …
        function mode(name: string): void { Shell.open("launcher"); console.log("TODO launcher mode", name) }
    }

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { Shell.toggle("cheatsheet") }
    }

    IpcHandler {
        target: "control"
        function toggle(): void { Shell.toggle("control") }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { Shell.toggle("notifications") }
        function dnd(): void { console.log("TODO toggle do not disturb") }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { Shell.toggle("wallpaper") }
    }

    IpcHandler {
        target: "overview"
        function toggle(): void { Shell.toggle("overview") }
    }

    IpcHandler {
        target: "switcher"
        function next(): void { console.log("TODO window switcher next") }
        function prev(): void { console.log("TODO window switcher prev") }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { Shell.toggle("power") }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { Shell.lock() }
    }

    IpcHandler {
        target: "capture"
        function region(): void { console.log("TODO capture region") }
        function record(): void { console.log("TODO start/stop recording") }
        function colorpicker(): void { console.log("TODO colour picker") }
        function screen(): void { console.log("TODO full screen to clipboard") }
    }

    IpcHandler {
        target: "gamemode"
        function toggle(): void { console.log("TODO game mode") }
    }

    IpcHandler {
        target: "keyhints"
        // Alt down / up. ("show" can't be a function name: `qs ipc call <target> show` lists the target.)
        function press(): void { KeyHints.held = true }
        function release(): void { KeyHints.held = false }
    }

    IpcHandler {
        target: "theme"
        function reload(): void { Theme.reload() }
    }

    IpcHandler {
        target: "glass"
        // Writes config.json, which also updates Hyprland's blur.
        function set(strength: string): void { Config.glass = strength }
        function get(): string { return Config.glass }
    }

    IpcHandler {
        target: "test"
        function toggle(): void { Shell.toggle("test") }
    }
}
