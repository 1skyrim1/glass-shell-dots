import QtQuick
import qs.services
import qs.components

// One card in the notification center (18-Notifications, 19-NotifStates): all of an app's notifications.
// - One notification: header "App · summary", the message, buttons, inline reply.
// - Several (a group): header "App", "3 new · 2 min", the last two messages (the newest muted);
//   Space expands the whole thread (2 px rule on the left, "name · 2 min" over each message) with
//   Collapse / Mark all read.
// - With an image (screenshot saved): thumbnail 84 × 48 next to the text. With progress: a green bar,
//   the message as its caption, updated in place.
// Selected (J/K): 1.5 px accent ring on accent 12 %. Critical: the error colours. Click = open,
// right-click = dismiss.
Rectangle {
    id: root

    property var group
    property Item nc   // the NotificationCenter
    property bool selected: false
    property bool expanded: false
    property bool replying: false
    signal clicked()

    readonly property var entries: group?.entries ?? []
    readonly property var newest: entries[0] ?? null
    readonly property bool multi: entries.length > 1
    readonly property int unread: entries.filter(e => !e.read).length
    readonly property bool critical: newest?.critical ?? false
    readonly property bool hasImage: !multi && (newest?.image ?? "") !== ""
    readonly property alias reply: replyField
    readonly property alias actionRow: actions

    function esc(s: string): string { return (s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;") }
    function line(e: var): string { return e.summary ? `<b>${esc(e.summary)}</b>  ${e.body}` : e.body }

    width: parent?.width ?? 0
    height: column.implicitHeight + 2 * pad
    readonly property real pad: Theme.px(12)
    radius: Theme.px(16)
    color: critical ? Theme.alpha(Theme.errorContainer, 0.55) : selected ? Theme.alpha(Theme.accent, 0.12) : Theme.white(0.07)
    border.width: selected ? Theme.px(1.5) : critical ? 1 : 0
    border.color: selected ? Theme.accent : Theme.alpha(Theme.error, 0.6)
    Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => {
            if (e.button === Qt.RightButton) Notifs.dismissGroup(root.group.key)
            else root.clicked()
        }
    }

    Column {
        id: column
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad

        // --- With an image: thumbnail + header + message side by side.
        Row {
            visible: root.hasImage
            width: parent.width
            spacing: Theme.px(12)
            Rectangle {
                id: thumb
                width: Theme.px(84)
                height: Theme.px(48)
                radius: Theme.px(8)
                color: Theme.white(0.06)
                border.width: 1
                border.color: Theme.white(0.15)
                clip: true
                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.hasImage ? root.newest.image : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: width * 2
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - thumb.width - parent.spacing
                spacing: Theme.px(4)
                NotifHeader {
                    width: parent.width
                    height: implicitHeight
                    entry: root.newest
                    showTile: false
                }
                Text {
                    width: parent.width
                    text: root.newest?.body ?? ""
                    textFormat: Text.StyledText
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12.5)
                }
            }
        }

        // --- Header
        NotifHeader {
            visible: !root.hasImage
            width: parent.width
            entry: root.newest
            title: root.multi ? root.newest.app : root.newest ? root.newest.app + (root.newest.summary ? " · " + root.newest.summary : "") : ""
            meta: !root.newest ? ""
                : root.newest.progress >= 0 && !root.multi ? root.newest.progress + " %"
                : (root.multi && root.unread > 0 ? root.unread + " new · " : "") + Notifs.metaOf(root.newest)
        }

        // --- One notification: its message (a progress bar's caption below the bar instead).
        readonly property bool single: !root.multi && !root.hasImage
        readonly property bool progress: single && (root.newest?.progress ?? -1) >= 0
        Gap { size: 8; shown: singleBody.visible }
        Text {
            id: singleBody
            visible: column.single && !column.progress && text !== ""
            width: parent.width
            text: root.newest?.body ?? ""
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            lineHeight: Theme.px(19)
            lineHeightMode: Text.FixedHeight
            color: root.critical ? Theme.textOnError : Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.px(13)
        }
        Gap { size: 10; shown: column.progress }
        ProgressLine {
            width: parent.width
            visible: column.progress
            value: root.newest?.progress ?? -1
        }
        Text {
            visible: column.progress && text !== ""
            width: parent.width
            topPadding: Theme.px(6)
            text: root.newest?.body ?? ""
            textFormat: Text.StyledText
            elide: Text.ElideRight
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.px(11.5)
        }

        // --- Group, collapsed: the last two messages in order, the newest one muted (as in the design).
        Gap { size: 8; shown: root.multi && !root.expanded }
        Text {
            visible: root.multi && !root.expanded
            width: parent.width
            text: root.multi ? root.line(root.entries[1]) : ""
            textFormat: Text.StyledText
            elide: Text.ElideRight
            lineHeight: Theme.px(19)
            lineHeightMode: Text.FixedHeight
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.px(13)
        }
        Text {
            visible: root.multi && !root.expanded
            width: parent.width
            topPadding: Theme.px(2)
            text: root.multi ? root.line(root.entries[0]) : ""
            textFormat: Text.StyledText
            elide: Text.ElideRight
            lineHeight: Theme.px(19)
            lineHeightMode: Text.FixedHeight
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.px(12.5)
        }

        // --- Group, expanded: the thread.
        Gap { size: 10; shown: thread.visible }
        Item {
            id: thread
            visible: root.multi && root.expanded
            width: parent.width
            height: threadCol.implicitHeight
            Rectangle {
                x: Theme.px(12)
                width: Theme.px(2)
                height: parent.height
                color: Theme.white(0.12)
            }
            Column {
                id: threadCol
                x: Theme.px(26)
                width: parent.width - x
                spacing: Theme.px(8)
                Repeater {
                    model: thread.visible ? root.entries : []
                    Text {
                        required property var modelData
                        width: threadCol.width
                        text: (modelData.summary ? `<b>${root.esc(modelData.summary)}</b> ` : "")
                              + `<font color="${Theme.textFaint}">${Notifs.metaOf(modelData)}</font><br>${modelData.body}`
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        lineHeight: Theme.px(18)
                        lineHeightMode: Text.FixedHeight
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.px(12.5)
                    }
                }
            }
        }

        // --- Buttons: the app's actions, or Collapse / Mark all read on an expanded group.
        Gap { size: 10; shown: actions.visible }
        ActionRow {
            id: actions
            entry: root.newest
            actions: root.multi && root.expanded
                ? [{ text: "Collapse", run: () => root.nc.toggleExpand(root.group.key) },
                   { text: "Mark all read", run: () => Notifs.markGroupRead(root.group.key) }]
                : root.newest?.actions ?? []
            keys: true
            radius: Theme.px(root.multi && root.expanded ? 15 : 10)
            onTriggered: a => root.multi && root.expanded ? a.run() : Notifs.act(root.newest, a)
        }

        // --- Inline reply, then "Sent ✓".
        Gap { size: 10; shown: replyField.visible }
        ReplyField {
            id: replyField
            visible: (root.newest?.replyable ?? false) && !root.newest.sent
            entry: root.newest
            active: root.replying
            keys: root.selected
            onActivate: root.nc.startReply(root.group.key)
            onLeave: root.nc.stopReply()
        }
        Text {
            visible: root.newest?.sent ?? false
            topPadding: Theme.px(8)
            text: "Sent ✓"
            color: Theme.good
            font.family: Theme.font
            font.pixelSize: Theme.px(11.5)
        }
    }
}
