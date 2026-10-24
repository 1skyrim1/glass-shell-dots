import QtQuick
import Quickshell.Widgets
import qs.services
import qs.components

// The media card (Control.dc.html): cover 48 px r12 (the track's art, else a note on the accent
// container), title, player · artist, a 4 px progress line, then previous · play/pause · next.
// Hidden while there's no MPRIS player. `focusCol` 0–2 = the button the keys are on (-1 = none).
Rectangle {
    id: root

    property int focusCol: -1
    readonly property var player: Media.player

    implicitHeight: Theme.px(68)
    radius: Theme.px(18)
    color: Theme.white(0.07)

    // Position isn't announced over MPRIS; poll while the card is on screen.
    Binding { target: Media; property: "watching"; value: root.visible && Shell.panel === "control"; when: Shell.panel === "control" }

    ClippingRectangle {
        id: cover
        x: Theme.px(10)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(48)
        height: width
        radius: Theme.px(12)
        color: Theme.accentContainer
        Icon {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            name: "music"
            size: Theme.px(22)
            color: Theme.textOnContainer
        }
        Image {
            id: art
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column {
        anchors { left: cover.right; leftMargin: Theme.px(12); right: buttons.left; rightMargin: Theme.px(12); verticalCenter: parent.verticalCenter }
        Text {
            width: parent.width
            text: Media.title
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.px(13)
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            readonly property string artist: root.player?.trackArtist ?? ""
            text: Media.label(root.player) + (artist !== "" ? " · " + artist : "")
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.px(11.5)
            elide: Text.ElideRight
        }
        Item { width: 1; height: Theme.px(7) }
        Rectangle {
            width: parent.width
            height: Theme.px(4)
            radius: height / 2
            color: Theme.white(0.14)
            Rectangle {
                height: parent.height
                radius: parent.radius
                width: parent.width * (Media.length > 0 ? Math.min(1, Media.position / Media.length) : 0)
                color: Theme.text
            }
        }
    }

    Row {
        id: buttons
        anchors { right: parent.right; rightMargin: Theme.px(10); verticalCenter: parent.verticalCenter }
        spacing: Theme.px(2)

        component Control: Button {
            id: control
            property string icon
            property int col
            focused: root.focusCol === col
            width: Theme.px(26)
            height: Theme.px(34)
            Icon { anchors.centerIn: parent; name: control.icon; size: Theme.px(16) }
        }

        Control { icon: "skip-back"; col: 0; onClicked: Media.previous() }
        Button {
            focused: root.focusCol === 1
            width: Theme.px(34)
            height: width
            base: Theme.text
            onClicked: Media.toggle()
            Icon {
                anchors.centerIn: parent
                name: Media.playing ? "pause" : "play"
                size: Theme.px(16)
                color: Theme.glassTint
            }
        }
        Control { icon: "skip-forward"; col: 2; onClicked: Media.next() }
    }
}
