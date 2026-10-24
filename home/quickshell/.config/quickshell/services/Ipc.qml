import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// One IpcHandler per surface; hyprland.lua binds call `qs ipc call <target> <function>` (DESIGN.md §6).
// List everything with `qs ipc show`. Surfaces that don't exist yet only track state in Shell.
Item {
    IpcHandler {
        target: "launcher"
        function toggle(): void { Shell.toggle("launcher") }
        // Open straight into a mode: "clipboard" (Super+V), "emoji" (Super+.), calc, command, files, web,
        // shortcuts. Calling it again for the mode that's showing closes the sheet.
        function mode(name: string): void {
            if (Shell.launcherOpen && Shell.launcherMode === name) Shell.closeAll()
            else Shell.openLauncher(name)
        }
    }

    IpcHandler {
        target: "clipboard"
        // Called by the wl-paste watcher in hyprland.lua after `cliphist store`: notes when and where
        // from the new entry was copied.
        function stored(): void { Clipboard.stored() }
    }

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { Shell.toggle("cheatsheet") }
    }

    IpcHandler {
        target: "control"
        function toggle(): void { Shell.toggle("control") }
        // Open straight at a place: "sound", "network" (Wi-Fi), "bluetooth", "nightlight" (the card grown),
        // "tray" (the first background app's menu) or "main".
        function open(where: string): void {
            if (!Shell.isOpen("control")) Shell.open("control")
            Shell.controlExpand = where === "nightlight" ? "nightlight" : ""
            Shell.controlSection = where === "bluetooth" ? "bluetooth" : "wifi"
            Shell.controlPage = where === "sound" ? "sound" : where === "network" || where === "bluetooth" ? "network" : ""
            Shell.controlTray = where === "tray" ? (SystemTray.items.values.find(i => i.hasMenu) ?? null) : null
        }
        function back(): void { Shell.controlTray ? (Shell.controlTray = null) : (Shell.controlPage = "") }
    }

    IpcHandler {
        target: "nightlight"
        function toggle(): void { NightLight.toggle() }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { Shell.toggle("notifications") }
        function dnd(): void { Modes.dnd = !Modes.dnd }
        // The bell's right-click menu (DND for a while, clear all).
        function menu(): void { Shell.togglePopover("bell", "") }
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
        // TODO Phase 9: Shell.lock() + the lock screen. Until then locking would only block every panel.
        function lock(): void { console.log("TODO lock screen") }
    }

    IpcHandler {
        target: "capture"
        function region(): void { console.log("TODO capture region") }
        // Placeholder until Phase 8: only the red pill and its timer.
        function record(): void { Modes.toggleRecording() }
        function colorpicker(): void { console.log("TODO colour picker") }
        function screen(): void { console.log("TODO full screen to clipboard") }
    }

    IpcHandler {
        target: "gamemode"
        function toggle(): void { Modes.gameMode = !Modes.gameMode }
    }

    IpcHandler {
        target: "keepawake"
        function toggle(): void { Modes.keepAwake = !Modes.keepAwake }
    }

    // Volume, brightness and layout keys: change the value and drop the OSD out of the clock.
    IpcHandler {
        target: "volume"
        function up(): void { Audio.up() }
        function down(): void { Audio.down() }
        function mute(): void { Audio.toggleMute() }
        function micmute(): void { Audio.toggleMicMute() }
    }

    IpcHandler {
        target: "brightness"
        function up(): void { Brightness.up() }
        function down(): void { Brightness.down() }
    }

    IpcHandler {
        target: "layout"
        function next(): void { Keyboard.next() }
        // The layout badge's right-click menu.
        function menu(): void { Shell.togglePopover("layout", "") }
    }

    IpcHandler {
        target: "media"
        function toggle(): void { Media.toggle() }
        function next(): void { Media.next() }
        function prev(): void { Media.previous() }
        function popover(): void { if (Media.player) Shell.togglePopover("media", "") }
    }

    IpcHandler {
        target: "workspaces"
        // Peek at a workspace without hovering its dot (closes with `popover close`).
        function peek(id: int): void { Shell.peekId = id; Shell.openPopover("peek", "") }
    }

    IpcHandler {
        target: "popover"
        function close(): void { Shell.closePopover() }
    }

    IpcHandler {
        target: "battery"
        // Fake a charge level (e.g. 12) to try the low-battery tint; -1 goes back to the real battery.
        function simulate(percent: int): void { Battery.simulated = percent }
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
