import QtQuick
import qs.services
import qs.components
import "../../components/fuzzy.js" as Fuzzy

// A launcher result (12-Launcher `.row`): 58 px, icon tile 40 r12, title 14.5 / 500 with the matched
// letters in accent 700, subtitle 12 faint, a note and a key cap at the end. `compact` is the 46 px row of
// the other modes (13-LauncherStates: tile 32 r10, 13.5 px). Selected = accent 16 % + 1 px accent 35 %.
Item {
    id: root

    signal clicked()

    property bool selected: false
    property bool compact: false
    property string title
    property var indices: []           // matched letters in the title
    property bool richTitle: false      // title is already rich text (may set a mono font: StyledText can't)
    property string subtitle
    property bool monoSubtitle: false
    property string note                // muted, at the end ("edited 4 min ago")
    property string key                 // key cap at the end (Alt only)
    property alias tile: tile
    default property alias extra: titleRow.data   // after the title (e.g. a mono command)

    width: parent?.width ?? 0
    implicitHeight: Theme.px(compact ? 46 : 58)

    Rectangle {
        anchors.fill: parent
        radius: Theme.px(compact ? 13 : 14)
        color: root.selected ? Theme.alpha(Theme.accent, 0.16) : mouse.containsMouse ? Theme.white(0.05) : "transparent"
        border.width: root.selected ? 1 : 0
        border.color: Theme.alpha(Theme.accent, 0.35)
        Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    AppTile {
        id: tile
        x: Theme.px(14) - (root.compact ? Theme.px(2) : 0)
        anchors.verticalCenter: parent.verticalCenter
        size: Theme.px(root.compact ? 32 : 40)
        iconSize: Theme.px(root.compact ? 16 : 20)
    }

    Column {
        anchors { left: tile.right; leftMargin: Theme.px(root.compact ? 12 : 14); right: end.left; rightMargin: Theme.px(10) }
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(2)
        Row {
            id: titleRow
            width: parent.width
            spacing: Theme.px(6)
            Text {
                id: titleText
                width: Math.min(implicitWidth, titleRow.width)
                text: root.richTitle ? root.title : Fuzzy.highlight(root.title, root.indices, Theme.accent)
                textFormat: root.richTitle ? Text.RichText : Text.StyledText
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.px(root.compact ? 13.5 : 14.5)
                font.weight: root.compact ? Font.Normal : Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
        Text {
            visible: root.subtitle !== ""
            width: parent.width
            text: root.subtitle
            color: Theme.textFaint
            font.family: root.monoSubtitle ? Theme.fontMono : Theme.font
            font.pixelSize: Theme.px(root.compact ? 11.5 : 12)
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
        }
    }

    Row {
        id: end
        anchors { right: parent.right; rightMargin: Theme.px(root.compact ? 12 : 14); verticalCenter: parent.verticalCenter }
        spacing: Theme.px(8)
        Text {
            visible: root.note !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.note
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.px(11.5)
        }
        KeyHint {
            visible: root.key !== "" && opacity > 0
            anchors.verticalCenter: parent.verticalCenter
            key: root.key
        }
    }
}
