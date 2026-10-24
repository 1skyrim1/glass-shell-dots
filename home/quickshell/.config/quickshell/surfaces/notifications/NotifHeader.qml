import QtQuick
import Quickshell
import qs.services
import qs.surfaces.launcher
import "../../components/apps.js" as AppIcons

// Header line of a toast or card (Notifications.dc.html `.hd`): app tile 26 px r8, "App · summary" in
// 12 px muted, and the age / "3 new · 2 min" on the right.
Row {
    id: root

    property var entry
    property string title: entry ? entry.app + (entry.summary ? " · " + entry.summary : "") : ""
    property string meta: entry ? Notifs.metaOf(entry) : ""
    property bool showTile: true
    property color textColor: entry?.critical ? Theme.textOnError : Theme.textMuted

    spacing: Theme.px(9)
    height: Theme.px(26)

    AppTile {
        visible: root.showTile
        anchors.verticalCenter: parent.verticalCenter
        size: Theme.px(26)
        iconSize: Theme.px(14)
        // The design's Lucide glyph when the app is a known one, else the app's own icon.
        readonly property string known: root.entry ? root.entry.icon || AppIcons.iconFor(`${root.entry.desktopEntry} ${root.entry.app}`) : ""
        icon: known !== "app-window" ? known : ""
        app: known === "app-window" && root.entry ? DesktopEntries.heuristicLookup(root.entry.desktopEntry || root.entry.app) : null
        colors: root.entry?.critical ? { fill: Theme.error, stroke: Theme.roles.on_error ?? Theme.textOnAccent } : root.entry?.colors ?? null
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - x - meta.width - root.spacing
        text: root.title
        elide: Text.ElideRight
        color: root.textColor
        font.family: Theme.font
        font.pixelSize: Theme.px(12)
    }
    Text {
        id: meta
        anchors.verticalCenter: parent.verticalCenter
        text: root.meta
        color: root.textColor
        font.family: Theme.font
        font.pixelSize: Theme.px(12)
    }
}
