import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import "apps.js" as Apps

// One window inside a scaled-down workspace (workspace peek, overview): placed where it sits on its monitor
// (lastIpcObject, fresh after Hyprland.refreshToplevels()), times `k`. A live capture of the window, and
// until its first frame the design's window tile (Overview.dc.html `.win`: dark tile, faint edge, app icon
// + title). `selected` = the 1.5 px accent edge of the focused window; `dimmed` = filtered out.
ClippingRectangle {
    id: root

    required property HyprlandToplevel toplevel
    property real k: 1               // scale from monitor px to preview px
    property real ox: 0              // where the monitor's (0, `reserved`) lands in the preview
    property real oy: 0
    property real monX: 0
    property real monY: 0
    property real reserved: 0        // the strip above the windows (the pills) that's cut off
    property bool live: true         // capture while shown
    property bool showLabel: true    // the icon + title tile (too small in the peek)
    property bool selected: false
    property bool dimmed: false

    readonly property var at: toplevel.lastIpcObject?.at ?? [0, 0]
    readonly property var size: toplevel.lastIpcObject?.size ?? [0, 0]
    readonly property string icon: Apps.iconFor(Apps.classOf(toplevel))

    x: ox + (at[0] - monX) * k
    y: oy + (at[1] - monY - reserved) * k
    width: size[0] * k
    height: size[1] * k
    radius: Theme.px(6)
    color: Theme.alpha(Qt.lighter(Theme.glassTint, 1.3), 0.94)
    opacity: dimmed ? 0.25 : 1
    Behavior on opacity { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }

    Column {
        anchors.centerIn: parent
        width: parent.width - Theme.px(12)
        spacing: Theme.px(4)
        visible: root.showLabel && !capture.hasContent
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: root.icon
            size: Theme.px(12)
            color: root.selected ? Theme.accent : Theme.text
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.toplevel.title
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.px(11)
        }
    }

    ScreencopyView {
        id: capture
        anchors.fill: parent
        captureSource: root.live ? root.toplevel.wayland : null
        live: root.live
        opacity: hasContent ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
    }

    // Edge on top of the capture: white 12 %, or the accent on the selected window.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: root.selected ? Theme.px(1.5) : 1
        border.color: root.selected ? Theme.accent : Theme.white(0.12)
    }
}
