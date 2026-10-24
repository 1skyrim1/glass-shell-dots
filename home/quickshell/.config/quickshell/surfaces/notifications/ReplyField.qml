import QtQuick
import qs.services
import qs.components

// Inline reply (18-Notifications card, 19-NotifStates "Inline reply"). At rest a 34 px field with the
// app's placeholder ("Reply to #quickshell") and the R key. R (or a click) grows it to 40 px with an accent
// ring and a send button; Enter sends, Esc leaves it and keeps the draft. After sending the card shows
// "Sent ✓" for a second and collapses (Notifs.reply).
Item {
    id: root

    property var entry
    property bool active: false   // typing in it
    property bool keys: true      // show the R key (only on the selected card)
    signal leave()

    width: parent?.width ?? 0
    height: Theme.px(active ? 40 : 34)
    Behavior on height { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }

    onActiveChanged: {
        if (active) {
            input.text = entry?.draft ?? ""
            input.cursorPosition = input.text.length
            input.forceActiveFocus()
        } else {
            // Give the keyboard back: a hidden field that keeps focus would still get the typing.
            input.focus = false
            input.text = ""
        }
    }
    function send() {
        const t = input.text
        root.leave()
        Notifs.reply(root.entry, t)
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.px(root.active ? 12 : 10)
        color: Theme.alpha(Theme.scrim, root.active ? 0.5 : 0.4)
        border.width: root.active ? 1 : 0
        border.color: Theme.alpha(Theme.accent, 0.5)
    }
    MouseArea {
        anchors.fill: parent
        enabled: !root.active
        onClicked: root.activate()
    }
    signal activate()   // asks the center to start replying here

    TextInput {
        id: input
        anchors { left: parent.left; leftMargin: Theme.px(12); right: send.left; rightMargin: Theme.px(8); verticalCenter: parent.verticalCenter }
        visible: root.active
        clip: true
        color: Theme.text
        selectionColor: Theme.alpha(Theme.accent, 0.35)
        font.family: Theme.font
        font.pixelSize: Theme.px(13)
        cursorDelegate: Rectangle {
            width: 2
            radius: 1
            color: Theme.accent
            visible: input.cursorVisible
        }
        onTextChanged: if (root.entry && root.active) root.entry.draft = text
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.send()
            else if (e.key === Qt.Key_Escape) root.leave()
            else return
            e.accepted = true
        }
    }
    Text {
        anchors { left: parent.left; leftMargin: Theme.px(12); right: send.left; rightMargin: Theme.px(8); verticalCenter: parent.verticalCenter }
        visible: !root.active || input.text === ""
        text: !root.active && root.entry?.draft ? root.entry.draft : root.entry?.placeholder ?? ""
        elide: Text.ElideRight
        color: !root.active && root.entry?.draft ? Theme.textMuted : Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.px(root.active ? 13 : 12.5)
    }
    Item {
        id: send
        anchors { right: parent.right; rightMargin: Theme.px(6); verticalCenter: parent.verticalCenter }
        width: root.active ? Theme.px(30) : hint.width
        height: Theme.px(30)
        KeyHint {
            id: hint
            anchors.centerIn: parent
            key: "R"
            visible: !root.active && root.keys && opacity > 0
        }
        Button {
            anchors.fill: parent
            visible: root.active
            base: Theme.accent
            onClicked: root.send()
            Icon {
                anchors.centerIn: parent
                name: "send"
                size: Theme.px(14)
                strokeWidth: 2.4
                color: Theme.textOnAccent
            }
        }
    }
}
