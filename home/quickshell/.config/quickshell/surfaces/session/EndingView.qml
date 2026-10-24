import QtQuick
import qs.services

// After Power off / Reboot / Log out (30-SessionStates "Shutting down"): the screen fades to black in 400 ms
// and a quiet Outfit label stays until the apps have closed, naming the one that's holding things up.
// Esc cancels, Enter closes the holdouts anyway (the owner's keys call Session.cancelEnd() / forceEnd()).
Rectangle {
    id: root

    readonly property string kind: Session.ending
    property string shownKind: ""
    onKindChanged: if (kind !== "") shownKind = kind

    color: "black"
    opacity: Session.endT
    visible: opacity > 0

    Text {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.37 - height / 2
        text: ({ poweroff: "Powering off", reboot: "Rebooting", logout: "Logging out" })[root.shownKind] ?? ""
        color: Theme.textOnContainer
        font.family: Theme.fontClock
        font.weight: Font.DemiBold
        font.pixelSize: Theme.px(34)
    }

    // Three dots, a light running through them.
    Row {
        id: dots
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.51
        spacing: Theme.px(10)
        property int lead: 0
        Timer {
            running: root.visible
            interval: Motion.dotStep
            repeat: true
            onTriggered: dots.lead = (dots.lead + 1) % 3
        }
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: Theme.px(10)
                height: width
                radius: width / 2
                color: Theme.accent
                opacity: [1, 0.6, 0.3][(index - dots.lead + 3) % 3]
                Behavior on opacity { NumberAnimation { duration: Motion.dotFade } }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.63
        text: Session.blocker !== "" ? `waiting for ${Session.blocker} to close…` : ""
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.px(14)
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(40)
        visible: Session.blocker !== ""
        text: Session.locked ? "closing it anyway in a moment" : "Enter closes it anyway · Esc cancels"
        color: Theme.alpha(Theme.textFaint, 0.6)
        font.family: Theme.font
        font.pixelSize: Theme.px(12)
    }
}
