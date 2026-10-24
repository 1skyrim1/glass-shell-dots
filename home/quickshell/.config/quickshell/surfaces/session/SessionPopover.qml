import QtQuick
import qs.services
import qs.components

// A popover of the greeter and the lock screen that grows up out of its chip (27-LoginUsers user switcher,
// 29-LockPower power options): popover glass, radius 24, padding 8, 10 px above the chips. It scales up from
// the chip's corner (§5.3 "Popovers": 200 ms, OutBack) and shrinks back in 60 % of that.
// Place it with x / y of its bottom corner; `fromRight` = it hangs from the right edge (power).
Item {
    id: root

    property bool shown: false
    property bool fromRight: false
    default property alias content: column.data

    width: Theme.px(280)
    height: column.implicitHeight + 2 * Theme.px(8)

    property real p: shown ? 1 : 0
    Behavior on p {
        NumberAnimation {
            duration: root.shown ? Motion.open(Motion.small) : Motion.close(Motion.small)
            easing.type: root.shown ? Motion.easeOpen : Motion.easeClose
            easing.overshoot: Motion.overshoot
        }
    }
    visible: p > 0.01
    opacity: Math.min(1, p * 1.6)
    scale: Motion.reduced ? 1 : 0.86 + 0.14 * p
    transformOrigin: fromRight ? Item.BottomRight : Item.BottomLeft

    GlassRect {
        anchors.fill: parent
        variant: "popover"
        radius: Theme.px(24)
    }
    Column {
        id: column
        x: Theme.px(8)
        y: Theme.px(8)
        width: root.width - 2 * x
    }
}
