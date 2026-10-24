import QtQuick
import Quickshell.Widgets
import qs.services

// A user's round picture: their ~/.face (or the greeter's copy of it), else the wallpaper, else a letter on
// a tinted circle (a user without a picture, Guest). `ring` adds the white 28 % ring + shadow of the big one.
Item {
    id: root

    property string source: ""     // file path; "" or unreadable → fallback
    property string fallback: ""   // second choice (the wallpaper)
    property string letter: "?"
    property bool ring: false

    implicitWidth: Theme.px(104)
    implicitHeight: implicitWidth

    readonly property bool hasImage: face.status === Image.Ready
    property bool useFallback: false
    onSourceChanged: useFallback = false

    // 0 0 0 3px white 28 %, 0 16 40 black 40 %
    Rectangle {
        visible: root.ring
        anchors.centerIn: parent
        width: parent.width + Theme.px(6)
        height: width
        radius: width / 2
        color: Theme.white(0.28)
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: width / 2
        // A letter avatar (Guest in 27-LoginUsers): deep green with a light green letter (fixed success hues).
        color: Qt.tint(Theme.glassTint, Theme.alpha(Theme.successContainer, 0.85))

        Text {
            anchors.centerIn: parent
            visible: !root.hasImage
            text: root.letter.toUpperCase()
            color: Theme.textOnSuccess
            font.family: Theme.fontClock
            font.weight: Font.DemiBold
            font.pixelSize: root.width * 0.42
        }
        Image {
            id: face
            anchors.fill: parent
            source: !root.useFallback && root.source !== "" ? "file://" + root.source
                  : root.fallback !== "" ? "file://" + root.fallback : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.width * 2, root.height * 2)
            asynchronous: true
            onStatusChanged: if (status === Image.Error && !root.useFallback) root.useFallback = true
        }
    }
}
