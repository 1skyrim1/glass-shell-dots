import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components
import "../../components/apps.js" as AppIcons

// An icon tile (12-Launcher `.tile`): a Lucide icon on a tile tinted per app from the matugen containers,
// or, for apps the Lucide set doesn't know, the app's own themed icon on a neutral tile. `neutral` =
// white 6 % tile with a muted icon (actions, web search, suggestions).
Rectangle {
    id: root

    property string icon: ""        // Lucide name; "" → derive from `app`
    property var app: null          // DesktopEntry
    property bool neutral: false
    property int tintIndex: -1      // force a tint (see apps.js tintFor), -1 = by name
    property real size: Theme.px(40)
    property real iconSize: size * 0.5
    property var colors: null       // { fill, stroke } instead of the tint (critical / catch-up notifications)

    readonly property string lucide: icon !== "" ? icon : AppIcons.iconFor(`${app?.id ?? ""} ${app?.startupClass ?? ""} ${app?.name ?? ""}`)
    readonly property string themed: icon === "" && lucide === "app-window" && app ? Quickshell.iconPath(app.icon, true) : ""
    readonly property int tint: tintIndex >= 0 ? tintIndex : AppIcons.tintFor(app?.name ?? icon, lucide)
    readonly property var fills: [Theme.tertiaryContainer, Theme.secondaryContainer, Theme.accentContainer]
    readonly property var strokes: [Theme.secondary, Theme.roles.on_secondary_container ?? Theme.text, Theme.accent]

    width: size
    height: size
    radius: size * 0.3
    color: colors ? colors.fill : neutral || themed !== "" ? Theme.white(0.06) : Theme.alpha(fills[tint], 0.6)

    Icon {
        anchors.centerIn: parent
        visible: root.themed === ""
        name: root.lucide
        size: root.iconSize
        color: root.colors ? root.colors.stroke : root.neutral ? Theme.textMuted : root.strokes[root.tint]
    }
    IconImage {
        anchors.centerIn: parent
        visible: root.themed !== ""
        source: root.themed
        implicitSize: root.size * 0.6
    }
}
