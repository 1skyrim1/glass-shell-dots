import QtQuick
import Quickshell.Widgets
import qs.services
import qs.components
import "../../components/apps.js" as AppIcons

// A background app's icon (Control.dc.html tray row): apps the Lucide set knows get its glyph on a tile
// tinted from the matugen containers (like the launcher's AppTile); others show their own tray icon on
// a neutral tile. Drawn inside whatever holds it (a button, the menu header).
Item {
    id: root

    property var item              // SystemTrayItem
    property real iconSize: Theme.px(16)

    readonly property string label: item?.tooltipTitle || item?.title || item?.id || ""
    readonly property string lucide: AppIcons.iconFor((item?.id ?? "") + " " + (item?.title ?? ""))
    readonly property bool known: lucide !== "app-window"
    readonly property int tint: AppIcons.tintFor(label, lucide)
    readonly property color fill: known ? Theme.alpha([Theme.tertiaryContainer, Theme.secondaryContainer, Theme.accentContainer][tint], 0.6)
                                        : Theme.white(0.08)
    readonly property color stroke: [Theme.secondary, Theme.roles.on_secondary_container ?? Theme.text, Theme.accent][tint]

    Icon {
        anchors.centerIn: parent
        visible: root.known
        name: root.lucide
        size: root.iconSize
        color: root.stroke
    }
    IconImage {
        anchors.centerIn: parent
        visible: !root.known
        source: root.known ? "" : root.item?.icon ?? ""
        implicitSize: root.iconSize * 1.15
    }
}
