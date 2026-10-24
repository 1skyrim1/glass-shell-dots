import QtQuick
import qs.services
import qs.components

// A notification's buttons (NotifStates.dc.html `.btn`, Notifications.dc.html): the first one on white
// 10 % (16 % on critical), the rest plain in muted text. Each shows its key while Alt is held: the first
// letter of its label, unless that letter is taken (J K R D T H L are the center's own keys).
Row {
    id: root

    property var entry
    property var actions: entry?.actions ?? []
    property bool keys: false        // show key hints (in the center, not on toasts)
    property real radius: Theme.px(15)
    readonly property bool critical: entry?.critical ?? false

    signal triggered(var action)

    spacing: Theme.px(6)
    visible: actions.length > 0

    // Key per button ("" = none), same for the center's key handling.
    readonly property var letters: keyLetters(actions)
    function keyLetters(list: var): var {
        const taken = new Set(["J", "K", "R", "D", "T", "H", "L"])
        return list.map(a => {
            const c = (a.text || "").charAt(0).toUpperCase()
            if (!/[A-Z]/.test(c) || taken.has(c)) return ""
            taken.add(c)
            return c
        })
    }

    Repeater {
        model: root.actions
        Button {
            id: button
            required property var modelData
            required property int index
            height: Theme.px(30)
            width: label.implicitWidth + Theme.px(24) + (hint.visible ? hint.width + Theme.px(6) : 0)
            radius: root.radius
            base: index === 0 ? Theme.white(root.critical ? 0.16 : 0.10) : "transparent"
            onClicked: root.triggered(modelData)

            Row {
                anchors.centerIn: parent
                spacing: Theme.px(6)
                Text {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter
                    text: button.modelData.text
                    color: button.index === 0 ? (root.critical ? Theme.textOnError : Theme.text)
                         : (root.critical ? Theme.alpha(Theme.textOnError, 0.8) : Theme.textMuted)
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12)
                }
                KeyHint {
                    id: hint
                    anchors.verticalCenter: parent.verticalCenter
                    key: root.letters[button.index] ?? ""
                    visible: root.keys && key !== "" && opacity > 0
                }
            }
        }
    }
}
