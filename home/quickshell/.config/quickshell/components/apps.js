.pragma library

// App icon (the design's Lucide set) by window class, desktop-entry id or app name; anything unknown
// gets a generic window ("app-window"; the launcher shows the app's own icon instead).
function iconFor(cls) {
    cls = (cls || "").toLowerCase()
    if (/kitty|foot|alacritty|wezterm|ghostty|terminal|konsole/.test(cls)) return "terminal"
    if (/discord|vesktop|webcord|element|telegram|signal|slack/.test(cls)) return "message-circle"
    if (/firefox|chrom|zen|librewolf|brave|vivaldi|browser/.test(cls)) return "globe"
    if (/steam|lutris|heroic|gamescope|^steam_app/.test(cls)) return "gamepad"
    if (/nautilus|thunar|dolphin|nemo|pcmanfm|files/.test(cls)) return "folder"
    if (/code|codium|zed|nvim|neovim/.test(cls)) return "code"
    if (/syncthing|nextcloud|dropbox/.test(cls)) return "refresh"
    return "app-window"
}

// Which tint an app's tile gets in the launcher (12-Launcher: browser warm, others vary): 0 = tertiary,
// 1 = secondary, 2 = primary container. Stable per name.
function tintFor(name, icon) {
    if (icon === "globe") return 0
    let h = 0
    for (const c of name || "") h = (h * 31 + c.charCodeAt(0)) >>> 0
    return h % 3
}

// Class of a HyprlandToplevel.
function classOf(w) { return w?.wayland?.appId || w?.lastIpcObject?.class || "" }
