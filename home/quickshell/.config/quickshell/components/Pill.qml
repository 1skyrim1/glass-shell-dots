import QtQuick
import qs.services

// A bar pill: 38 px glass capsule with pointer handling (DESIGN.md §2, §4 "Mouse"). Hover / press feed
// GlassRect's states; left click, right click and scroll come out as signals. Children go on top of the
// mouse area, so a child with its own MouseArea (a workspace dot, the layout badge) takes its clicks first.
GlassRect {
    id: root

    signal clicked()
    signal rightClicked()
    signal scrolled(int step)   // +1 = down (next), −1 = up (previous); touchpad deltas add up to steps

    implicitHeight: Theme.px(38)
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    // Pills hug their content; width changes animate (§5.3 "pill width animates"), unless the pill
    // drives its width with its own animation.
    property bool animateWidth: true
    Behavior on implicitWidth {
        enabled: root.animateWidth && !Motion.reduced
        NumberAnimation { duration: Motion.pillWidth; easing.type: Motion.easeSmall }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()

        property real wheel: 0
        onWheel: e => {
            wheel += e.angleDelta.y
            while (Math.abs(wheel) >= 120) {
                const step = wheel > 0 ? -1 : 1
                wheel += step * 120
                root.scrolled(step)
            }
        }
    }
}
