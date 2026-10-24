import QtQuick
import qs.services

// Key cap (DESIGN.md §1.3). Hidden until Alt is held; set alwaysVisible for the cheatsheet.
// On a solid button (accent Capture, red Start) set `ink` to the button's text colour: the cap is then tinted
// with it instead of white (CaptureRegion.dc.html `.act .kbd`).
Rectangle {
    id: root

    property string key
    property bool alwaysVisible: false
    property color ink: "transparent"
    readonly property bool inked: ink.a > 0

    implicitWidth: label.implicitWidth + Theme.px(12) + 2
    implicitHeight: label.implicitHeight + Theme.px(4) + 2
    radius: Theme.px(6)
    color: inked ? Theme.alpha(ink, 0.15) : Theme.white(0.10)
    border.width: 1
    border.color: inked ? Theme.alpha(ink, 0.25) : Theme.white(0.16)

    opacity: alwaysVisible || KeyHints.held ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.key
        font.family: Theme.fontMono
        font.pixelSize: Theme.px(11)
        color: root.inked ? root.ink : Theme.text
    }
}
