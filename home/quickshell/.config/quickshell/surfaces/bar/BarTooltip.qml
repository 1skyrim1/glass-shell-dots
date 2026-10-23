import QtQuick
import qs.services
import qs.components

// The bar's one tooltip (DESIGN.md §3.1, 10-Popovers "Tooltips"): glass, 30 px tall, radius 15, one line,
// 8 px under the pills (never covering them), centred on the hovered icon and kept on screen. Shown for the
// TipArea in Shell.tip; hidden while a popover or panel is open.
Item {
    id: root

    anchors.fill: parent
    readonly property alias body: glass

    // Only the tooltip of an icon on this bar's window.
    readonly property Item tip: Shell.tip && Shell.tip.Window.window === root.Window.window
                                && Shell.popover === "" && Shell.panel === "" ? Shell.tip : null
    readonly property bool shown: tip !== null
    // Keeps the last tooltip's text while it fades out.
    property string text
    property string icon
    property real centre
    onTipChanged: {
        if (!tip) return
        const t = tip.mapToItem(root, 0, 0, tip.width, tip.height)
        centre = t.x + t.width / 2
    }
    Binding { when: root.shown; root.text: root.tip?.text ?? "" }
    Binding { when: root.shown; root.icon: root.tip?.icon ?? "" }

    GlassRect {
        id: glass
        readonly property real inset: Theme.px(12)
        x: Math.max(inset, Math.min(root.width - inset - width, root.centre - width / 2))
        y: Theme.px(10 + 38 + 8) - (root.shown ? 0 : Theme.px(4))
        width: row.implicitWidth + Theme.px(24)
        height: Theme.px(30)
        opacity: root.shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
        Behavior on y { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
        Behavior on x { enabled: glass.opacity > 0; NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.px(8)
            Icon {
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                size: Theme.px(13)
            }
            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                font.pixelSize: Theme.px(12.5)
            }
        }
    }
}
