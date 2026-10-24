import QtQuick
import qs.services
import qs.components

// What a toast shows (Notifications.dc.html toast, NotifStates.dc.html): header, message (13 px, up to
// three lines), progress, buttons, the draining timer line (3 px accent) and, while Alt is held,
// "Super N  open and reply". Critical ones have no timer and use the error colours.
Column {
    id: root

    property var entry
    property real remaining: 1   // timer left, 1 → 0
    property bool timed: true

    readonly property bool critical: entry?.critical ?? false

    NotifHeader {
        width: parent.width
        entry: root.entry
    }
    Gap { size: 7; shown: body.visible }
    Text {
        id: body
        width: parent.width
        visible: text !== ""
        text: root.entry?.body ?? ""
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
        lineHeight: Theme.px(19)
        lineHeightMode: Text.FixedHeight
        color: root.critical ? Theme.textOnError : Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.px(13)
    }
    Gap { size: 10; shown: progress.visible }
    ProgressLine {
        id: progress
        width: parent.width
        value: root.entry?.progress ?? -1
    }
    Gap { size: 10; shown: actions.visible }
    ActionRow {
        id: actions
        entry: root.entry
        onTriggered: a => Notifs.act(root.entry, a)
    }
    Gap { size: 9; shown: timer.visible }
    Rectangle {
        id: timer
        visible: root.timed
        width: parent.width
        height: Theme.px(3)
        radius: height / 2
        color: Theme.white(0.12)
        Rectangle {
            width: parent.width * root.remaining
            height: parent.height
            radius: parent.radius
            color: Theme.accent
        }
    }
    Gap { size: 9; shown: hint.visible }
    Row {
        id: hint
        visible: KeyHints.held
        spacing: Theme.px(6)
        KeyHint { key: "Super N"; anchors.verticalCenter: parent.verticalCenter }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "open and reply"
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.px(11.5)
        }
    }
}
