import QtQuick
import qs.services

// A 1 px white 10 % line between menu groups (Popovers.dc.html `.sep`: margin 5 px 6 px).
Item {
    property real inset: Theme.px(6)
    property real above: Theme.px(5)
    property real below: Theme.px(5)
    width: parent?.width ?? 0
    height: above + 1 + below
    Rectangle {
        x: parent.inset
        y: parent.above
        width: parent.width - 2 * parent.inset
        height: 1
        color: Theme.white(0.10)
    }
}
