import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.services

// One wallpaper in the switcher strip (20-Wallpaper): 194 × 109, r16, a thin white edge and the name
// bottom-left. The selected one grows to 240 × 135 with a 2 px accent ring and a 5 px halo; sizes are
// outer (CSS content-box + border). press() is Enter's dip to 94 % (07-MotionWallpaper).
Item {
    id: root

    required property var item
    property bool selected: false
    signal clicked()

    width: Theme.px(selected ? 244 : 196)
    height: Theme.px(selected ? 139 : 111)
    Behavior on width { enabled: !Motion.reduced; NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
    Behavior on height { enabled: !Motion.reduced; NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }

    readonly property real radius: Theme.px(16)
    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1

    function press() { if (!Motion.reduced) pressAnim.restart() }
    SequentialAnimation {
        id: pressAnim
        NumberAnimation { target: root; property: "scale"; to: 0.94; duration: Motion.micro; easing.type: Motion.easeMicro }
        NumberAnimation { target: root; property: "scale"; to: 1; duration: Motion.micro; easing.type: Motion.easeMicro }
    }

    // Halo (box-shadow 0 0 0 5px accent 22 %)
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Theme.px(5)
        radius: root.radius + Theme.px(5)
        color: Theme.alpha(Theme.accent, 0.22)
        opacity: root.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.glassTint

        Image {
            anchors.fill: parent
            source: "file://" + root.item.path
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // Decoded once at the selected size, so growing doesn't reload it.
            sourceSize: Qt.size(Theme.px(244) * root.dpr, Theme.px(139) * root.dpr)
        }

        Text {
            x: Theme.px(10) + (root.selected ? 1 : 0)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.px(8) + (root.selected ? 1 : 0)
            text: root.item.name
            color: Theme.white(1)
            font.family: Theme.font
            font.pixelSize: Theme.px(12)
            font.weight: Font.DemiBold
            // text-shadow 0 1px 4px black 60 %
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.6)
                shadowBlur: 0.4
                shadowVerticalOffset: Theme.px(1)
            }
        }
    }

    // Edge on top of the picture: white 14 %, or the accent ring when selected.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? Theme.accent : Theme.white(0.14)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
