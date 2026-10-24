import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.services

// Magnifier over the frozen frame (21-CaptureRegion loupe, 24-CaptureExtras colour picker): a circle showing
// the pixels around `pixel` (physical px) as `cell`-sized squares with a faint grid. Region mode marks the
// centre with an accent crosshair; the colour picker boxes the centre pixel instead.
Item {
    id: root

    property string source
    property point pixel
    property size frame                 // the frozen frame's size in px
    property real cell: Theme.px(13)    // one pixel on screen
    property bool boxed: false          // colour picker: box the centre pixel, no crosshair
    property real ring: Theme.px(2)
    property color ringColor: Theme.white(0.7)

    width: Theme.px(104)
    height: width

    // Drop shadow 0 10 30 black 50 %.
    RectangularShadow {
        anchors.fill: parent
        radius: width / 2
        offset.y: Theme.px(10)
        blur: Theme.px(30)
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: width / 2
        color: "black"

        // The whole frame, one source pixel = `cell`, moved so `pixel` sits in the middle.
        Image {
            source: root.source
            cache: true
            smooth: false
            width: root.frame.width
            height: root.frame.height
            scale: root.cell
            transformOrigin: Item.TopLeft
            x: root.width / 2 - (root.pixel.x + 0.5) * root.cell
            y: root.height / 2 - (root.pixel.y + 0.5) * root.cell
        }

        // Pixel grid: black 18 % lines on the pixel edges.
        Repeater {
            model: Math.ceil(root.width / root.cell) + 1
            Rectangle {
                required property int index
                x: (root.width / 2 - root.cell / 2) % root.cell + index * root.cell - root.cell
                width: 1
                height: root.height
                color: Qt.rgba(0, 0, 0, root.boxed ? 0.14 : 0.18)
            }
        }
        Repeater {
            model: Math.ceil(root.height / root.cell) + 1
            Rectangle {
                required property int index
                y: (root.height / 2 - root.cell / 2) % root.cell + index * root.cell - root.cell
                width: root.width
                height: 1
                color: Qt.rgba(0, 0, 0, root.boxed ? 0.14 : 0.18)
            }
        }

        // Region: accent crosshair through the centre pixel (4 px wide).
        Rectangle {
            visible: !root.boxed
            x: root.width / 2 - width / 2
            width: Theme.px(4)
            height: root.height
            color: Theme.accent
        }
        Rectangle {
            visible: !root.boxed
            y: root.height / 2 - height / 2
            width: root.width
            height: Theme.px(4)
            color: Theme.accent
        }
        // Colour picker: the centre pixel boxed (2 px dark border).
        Rectangle {
            visible: root.boxed
            anchors.centerIn: parent
            width: root.cell
            height: root.cell
            color: "transparent"
            border.width: Theme.px(2)
            border.color: Theme.markBlack
        }
    }

    // Ring
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: root.ring
        border.color: root.ringColor
    }
}
