pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colours, fonts and scale (DESIGN.md §1). Colours come from matugen's JSON and reload when it changes;
// default-colors.json (a saved matugen output) is used until the generated file exists.
Singleton {
    id: root

    // Designs are drawn at 1600 px wide; px() turns a design value into logical pixels.
    readonly property real scale: (Quickshell.screens[0]?.width ?? 1600) / 1600
    function px(v: real): real { return Math.round(v * scale * 2) / 2 }

    // Raw matugen roles, keyed by matugen name: the applied theme (colors.json).
    property var roles: ({})
    // The wallpaper switcher's palette while browsing (services/Wallpapers.qml), null otherwise.
    property var preview: null
    // What the colours are heading to.
    readonly property var target: preview ?? roles

    // Every change of target cross-fades all colours together (§5.3 "browsing cross-fades accents",
    // Esc fades back): `from` is what was on screen when the target changed, t runs 0 → 1.
    property var from: ({})
    property real t: 1
    onTargetChanged: {
        const shown = {}
        for (const k in target) if (k !== "wallpaper") shown[k] = role(k)
        from = shown
        t = 0
        fadeAnim.restart()
    }
    NumberAnimation { id: fadeAnim; target: root; property: "t"; to: 1; duration: Motion.themeFade; easing.type: Easing.InOutCubic }
    function role(name: string): color {
        const b = target[name]
        if (!b) return "transparent"
        const a = from[name]
        return a && t < 1 ? Qt.tint(a, alpha(b, t)) : b
    }

    // Spec names → matugen roles (§1.1)
    readonly property color accent: role("primary")
    readonly property color textOnAccent: role("on_primary")
    readonly property color accentContainer: role("primary_container")
    readonly property color textOnContainer: role("on_primary_container")
    readonly property color text: role("on_surface")
    readonly property color textMuted: role("on_surface_variant")
    readonly property color textFaint: role("outline")
    readonly property color secondary: role("tertiary")
    // Tints for launcher icon tiles (one per app, picked by name)
    readonly property color secondaryContainer: role("secondary_container")
    readonly property color tertiaryContainer: role("tertiary_container")
    readonly property color scrim: role("scrim")   // dims the desktop behind sheets
    readonly property color glassTint: role("surface_dim")
    readonly property color error: role("error")
    readonly property color errorContainer: role("error_container")
    readonly property color textOnError: role("on_error_container")
    readonly property string wallpaper: roles.wallpaper ?? ""

    // Fixed status colours (not from matugen)
    readonly property color warning: "#FFB36B"
    readonly property color warningContainer: Qt.rgba(110 / 255, 60 / 255, 16 / 255, 0.45)
    readonly property color textOnWarning: "#FFE2C7"
    readonly property color successContainer: Qt.rgba(20 / 255, 80 / 255, 50 / 255, 0.5)
    readonly property color successBorder: Qt.rgba(140 / 255, 230 / 255, 180 / 255, 0.5)
    readonly property color textOnSuccess: "#D4F7E2"
    readonly property color good: "#C5E3B4"
    // Night light (17-ControlPages): the card uses the warning colours, its slider runs warm → cool
    // like the colour temperature itself, so these don't follow the wallpaper either.
    readonly property color nightWarm: "#FF9E57"
    readonly property color nightCool: "#FFE7C2"
    readonly property color textOnNight: "#FFD6B3"

    readonly property string font: "Geist"
    readonly property string fontMono: "Geist Mono"
    readonly property string fontClock: "Outfit"

    function alpha(c: color, a: real): color { return Qt.rgba(c.r, c.g, c.b, a) }
    // The glass recipe's white borders and highlights
    function white(a: real): color { return Qt.rgba(1, 1, 1, a) }

    function reload() { generated.reload() }

    FileView {
        id: generated
        path: Quickshell.env("HOME") + "/.local/state/glass-shell/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.roles = JSON.parse(text()) } catch (e) { console.warn("Theme: bad colors.json", e) }
        }
        onLoadFailed: if (!root.roles.primary) root.roles = JSON.parse(fallback.text())
    }

    FileView {
        id: fallback
        path: Quickshell.shellDir + "/default-colors.json"
        blockLoading: true
    }
}
