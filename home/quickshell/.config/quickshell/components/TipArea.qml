import QtQuick
import qs.services

// Put inside an icon to give it a tooltip (DESIGN.md §3.1): after 600 ms of hover the bar's tooltip shows
// `text` under the pill. Passive, so the pill still gets its hover, clicks and scrolls.
// Only for icons whose state isn't readable at a glance.
Item {
    id: root

    property string text
    property string icon

    anchors.fill: parent

    HoverHandler {
        id: hover
        onHoveredChanged: hovered ? delay.restart() : (delay.stop(), Shell.hideTip(root))
    }
    Timer {
        id: delay
        interval: Motion.tipDelay
        onTriggered: Shell.showTip(root)
    }
    Component.onDestruction: Shell.hideTip(root)
}
