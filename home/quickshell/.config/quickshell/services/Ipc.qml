import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// One IpcHandler per surface; Hyprland's binds (conf/binds.lua) call `qs ipc call <target> <function>` (DESIGN.md §6).
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
        // Called by the wl-paste watcher in Hyprland's conf/session.lua after `cliphist store`: notes when and where
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
        function dnd(): void { Modes.dnd ? (Modes.dnd = false) : Modes.setDnd("manual") }
        // The bell's right-click menu (DND for a while, clear all).
        function menu(): void { Shell.togglePopover("bell", "") }
        function clear(): void { Notifs.clearAll() }
    }

    IpcHandler {
        target: "calendar"
        // Re-read khal (e.g. after `khal new`).
        function refresh(): void { Calendar.refresh() }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { Shell.toggle("wallpaper") }
        // Browse like ←/→ and R (opening the switcher first), apply like Enter.
        // Nothing while locked or while a password prompt is up (the switcher can't open then, and a preview
        // without it would never be reverted).
        function next(): void { if (browsable()) Wallpapers.browse(1) }
        function prev(): void { if (browsable()) Wallpapers.browse(-1) }
        function random(): void { if (browsable()) Wallpapers.random() }
        function browsable(): bool {
            if (!Wallpapers.open) Shell.open("wallpaper")
            return Shell.isOpen("wallpaper")
        }
        function apply(): void { if (Wallpapers.open) Wallpapers.applyRequested() }
        // Apply one by name ("fjord"), without the switcher; `list` names them, the applied one marked *.
        function set(name: string): string { return Wallpapers.applyNamed(name) ? "ok" : "no wallpaper " + name }
        function list(): string {
            return Wallpapers.items.map(i => (i.file === Wallpapers.appliedFile ? "* " : "  ") + i.name).join("\n")
        }
    }

    IpcHandler {
        target: "overview"
        function toggle(): void { Shell.toggle("overview") }
        function state(): string { return JSON.stringify({ open: Shell.isOpen("overview") }) }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { Shell.toggle("power") }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { Session.lock(false) }
        // The lock screen on an ordinary layer with fake auth ("wrong" fails, anything else unlocks; Esc leaves).
        function preview(): void { Session.startPreview() }
        // Preview only: type into it without a keyboard.
        function type(text: string): void { if (Session.preview) Session.submit(text) }
        function state(): string {
            return JSON.stringify({ phase: Session.phase, preview: Session.preview, status: Session.status,
                                    failures: Session.failures, waitLeft: Session.waitLeft, barT: Session.barT })
        }
    }

    IpcHandler {
        target: "session"
        // The power menu's actions without the menu (logout / reboot / poweroff show the shutting-down screen).
        function suspend(): void { Session.suspend() }
        function logout(): void { Session.end("logout") }
        function reboot(): void { Session.end("reboot") }
        function poweroff(): void { Session.end("poweroff") }
        function cancel(): void { Session.cancelEnd() }
        // Like Enter on that screen: close the apps that are still open anyway.
        function force(): void { Session.forceEnd() }
        // The shutting-down screen without closing or running anything (Esc or `cancel` ends it).
        function preview(kind: string): void { Session.previewEnd(kind || "poweroff") }
    }

    IpcHandler {
        target: "idle"
        // Squeeze the idle chain so the lock comes `seconds` after the last input (0 = normal times again).
        function test(seconds: int): void { Idle.factor = seconds > 0 ? seconds / Config.idle.lock : 1 }
        function state(): string {
            return JSON.stringify({ factor: Idle.factor, lockAfter: Idle.lockAfter, warnAfter: Idle.warnAfter, countdown: Idle.countdown })
        }
    }

    IpcHandler {
        target: "polkit"
        function cancel(): void { Polkit.cancel() }
        function state(): string {
            const f = Polkit.flow
            return JSON.stringify({ active: Polkit.active, status: Polkit.status, failures: Polkit.failures,
                                    message: f?.message ?? "", action: f?.actionId ?? "", prompt: f?.inputPrompt ?? "",
                                    identity: f?.selectedIdentity?.displayName ?? "", program: Polkit.program, pid: Polkit.pid })
        }
    }

    IpcHandler {
        target: "capture"
        // Super+Shift+S: the tool in its last mode. `region` / `window` / `screen` open (or switch) straight to one.
        function open(): void { Capture.open("", "") }
        function region(): void { Capture.open("region", "") }
        function window(): void { Capture.open("window", "") }
        function screen(): void { Capture.open("screen", "") }
        // Print: the whole focused screen to the clipboard (+ saved), no tool. ("print" is reserved in QML.)
        function shot(): void { Capture.screenNow() }
        // Super+Shift+R: stops a recording, otherwise opens the tool in Record mode.
        function record(): void { Recorder.toggle() }
        function colorpicker(): void { Capture.openPicker() }
        // Opens Annotate on an image (the last screenshot if the path is empty).
        function annotate(path: string): void { Capture.annotate(path) }
        function close(): void { Capture.close() }
        // Testing Annotate without a pointer: a mark in image px (kind: arrow rect pen text highlight blur crop).
        function mark(kind: string, x1: int, y1: int, x2: int, y2: int, text: string): void {
            Capture.testMark({ kind: kind, x1: x1, y1: y1, x2: x2, y2: y2, text: text,
                               points: kind === "pen" ? [[x1, y1], [(x1 + x2) / 2, y1 - 20], [x2, y2]] : undefined })
        }
        // Enter: capture / start recording.
        function take(): void { Capture.capture() }
        // Testing without a pointer: set the region selection (physical px) or the cursor.
        function select(x: int, y: int, w: int, h: int): void { Capture.selection = { x: x, y: y, w: w, h: h } }
        function cursor(x: int, y: int): void { Capture.cursorPos = Qt.point(x, y) }
        function state(): string {
            return JSON.stringify({ phase: Capture.phase, tool: Capture.tool, mode: Capture.mode, kind: Capture.kind,
                cursor: [Capture.cursorPos.x, Capture.cursorPos.y], selection: Capture.selection, pick: Capture.hex(Capture.pickColor),
                target: Capture.target, windows: Capture.windows.length, lastShot: Capture.lastShot, card: Capture.cardShown })
        }
    }

    IpcHandler {
        target: "share"
        // Called by glass-share-picker (system/usr/local/bin/) (xdg-desktop-portal-hyprland's custom picker); the answer goes
        // into `fifo`. token = "1" if the app may be remembered; app = the portal's app id (may be empty).
        function pick(fifo: string, list: string, token: string, app: string): void { Share.pick(fifo, list, token, app) }
        function stop(): void { Share.stop() }
        // Show the green pill as if sharing <label> ("" ends it), to try it without a portal session.
        function simulate(label: string): void { Share.label = label || Share.label; Share.sharing = label !== "" }
    }

    IpcHandler {
        target: "recorder"
        function stop(): void { Recorder.stop() }
        function trim(): void { Recorder.openTrim() }
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
