import QtQuick
import qs.services
import qs.components

// The coloured password pill of the greeter and the lock screen (26-Login, 28-Lock, 30-SessionStates):
// 320 × 52, accent container 45 % + accent edge + a 5 px accent halo, a dot per typed character and the
// caret, the 40 px accent go button. States:
//   ""         dots (or the placeholder) + arrow
//   "checking" dots dim, the arrow turns into a spinner, typing is blocked
//   "wrong"    red pill "Wrong password" with a × button; shakes (±8, ±8, ±5, ±4 px)
//   "wait"     stays red while the wait counts down (the line under it says how long)
// The text itself lives in the surface's hidden TextInput; this only draws it.
Item {
    id: root

    property int count: 0
    property string placeholder: "Enter password"
    property string status: ""
    property bool caret: true   // the field has the keyboard

    signal goClicked()

    readonly property bool red: status === "wrong" || status === "wait"
    implicitWidth: Theme.px(320)
    implicitHeight: Theme.px(52)

    // --- Shake on every wrong password
    property real shakeT: 1
    onStatusChanged: if (status === "wrong" && Motion.shake) shake.restart()
    NumberAnimation { id: shake; target: root; property: "shakeT"; from: 0; to: 1; duration: Motion.shakeTime }

    Item {
        id: body
        width: root.width
        height: root.height
        x: Motion.frames(root.shakeT, Motion.shakeKeys) * Theme.px(1)
        opacity: root.status === "checking" ? 0.85 : 1

        // 0 0 0 5px accent 16 % (red: error 20 %)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -Theme.px(5)
            radius: height / 2
            color: root.red ? Theme.alpha(Theme.error, 0.2) : Theme.alpha(Theme.accent, 0.16)
            Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
        }
        GlassRect {
            anchors.fill: parent
            variant: "chip"
            tone: root.red ? "wrong" : "field"
        }

        // Dots + caret, or the placeholder / message.
        Row {
            x: Theme.px(22)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(7)
            visible: root.count > 0 && !root.red
            Repeater {
                model: Math.min(root.count, 18)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(9)
                    height: width
                    radius: width / 2
                    color: Theme.textOnContainer
                    opacity: root.status === "checking" ? 0.5 : 1
                }
            }
            Rectangle {
                id: caretBar
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(2)
                height: Theme.px(20)
                color: Theme.textOnContainer
                visible: root.caret && root.status === ""
                SequentialAnimation on opacity {
                    running: caretBar.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 1; duration: 0 }
                    PauseAnimation { duration: Motion.caretBlink }
                    NumberAnimation { to: 0; duration: 0 }
                    PauseAnimation { duration: Motion.caretBlink }
                }
            }
        }
        Text {
            x: Theme.px(22)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - Theme.px(56)
            visible: root.count === 0 || root.red
            text: root.red ? "Wrong password" : root.placeholder
            elide: Text.ElideRight
            color: root.red ? Theme.textOnError : Theme.textOnContainer
            opacity: root.red ? 1 : 0.9
            font.family: Theme.font
            font.pixelSize: Theme.px(14)
        }

        // Go button: arrow · spinner (checking) · × (wrong)
        Button {
            anchors.right: parent.right
            anchors.rightMargin: Theme.px(6)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(40)
            height: width
            base: root.status === "checking" ? "transparent" : root.red ? Theme.error : Theme.accent
            enabled: root.status === ""
            opacity: 1
            onClicked: root.goClicked()

            Icon {
                anchors.centerIn: parent
                visible: root.status !== "checking"
                name: root.red ? "x" : "arrow-right"
                size: Theme.px(root.red ? 14 : 16)
                strokeWidth: root.red ? 3 : 2.4
                color: root.red ? Theme.textOnErrorStrong : Theme.textOnAccent
            }
            Ring {
                anchors.centerIn: parent
                width: Theme.px(26)
                visible: root.status === "checking"
                spinning: true
                color: Theme.textOnContainer
            }
        }
    }
}
