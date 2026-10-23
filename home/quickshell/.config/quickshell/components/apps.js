.pragma library

// App icon (the design's Lucide set) by window class; anything unknown gets a generic window.
function iconFor(cls) {
    cls = (cls || "").toLowerCase()
    if (/kitty|foot|alacritty|wezterm|ghostty|terminal/.test(cls)) return "terminal"
    if (/discord|vesktop|webcord|element|telegram|signal|slack/.test(cls)) return "message-circle"
    if (/firefox|chrom|zen|librewolf|brave|vivaldi|browser/.test(cls)) return "globe"
    if (/steam|lutris|heroic|gamescope|^steam_app/.test(cls)) return "gamepad"
    if (/nautilus|thunar|dolphin|nemo|pcmanfm|files/.test(cls)) return "folder"
    if (/code|codium|zed/.test(cls)) return "code"
    return "app-window"
}

// Class of a HyprlandToplevel.
function classOf(w) { return w?.wayland?.appId || w?.lastIpcObject?.class || "" }
