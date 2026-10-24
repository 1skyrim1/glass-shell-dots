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

    // Raw matugen roles, keyed by matugen name.
    property var roles: ({})

    // Spec names → matugen roles (§1.1)
    readonly property color accent: roles.primary ?? "transparent"
    readonly property color textOnAccent: roles.on_primary ?? "transparent"
    readonly property color accentContainer: roles.primary_container ?? "transparent"
    readonly property color textOnContainer: roles.on_primary_container ?? "transparent"
    readonly property color text: roles.on_surface ?? "transparent"
    readonly property color textMuted: roles.on_surface_variant ?? "transparent"
    readonly property color textFaint: roles.outline ?? "transparent"
    readonly property color secondary: roles.tertiary ?? "transparent"
    // Tints for launcher icon tiles (one per app, picked by name)
    readonly property color secondaryContainer: roles.secondary_container ?? "transparent"
    readonly property color tertiaryContainer: roles.tertiary_container ?? "transparent"
    readonly property color scrim: roles.scrim ?? "transparent"   // dims the desktop behind sheets
    readonly property color glassTint: roles.surface_dim ?? "transparent"
    readonly property color error: roles.error ?? "transparent"
    readonly property color errorContainer: roles.error_container ?? "transparent"
    readonly property color textOnError: roles.on_error_container ?? "transparent"
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
