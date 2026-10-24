import QtQuick
import qs.services

// Progress of a long task (19-NotifStates "Progress"): 6 px bar in the fixed "good" green on white 12 %.
// The app sends the same notification again with a new value; the fill follows it.
Rectangle {
    id: root

    property int value: -1   // 0–100, −1 = hidden

    visible: value >= 0
    height: Theme.px(6)
    radius: height / 2
    color: Theme.white(0.12)
    Rectangle {
        width: parent.width * Math.max(0, Math.min(100, root.value)) / 100
        height: parent.height
        radius: parent.radius
        color: Theme.good
        Behavior on width { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
    }
}
