import QtQuick
import qs.services
import qs.components

// Wallpaper switcher (DESIGN.md §3.6, 20-Wallpaper): Super+W. A glass sheet at the bottom with one
// thumbnail per wallpaper, and below it the selected one's name, its four palette colours and
// "previewing live". No options. Keys: ←/→ (H/L) browse (the whole shell previews the palette), Enter
// applies (the wallpaper ripples out of the thumbnail while the sheet sinks), R random, Esc reverts.
// Mouse: click a thumbnail to preview it, click it again to apply; scroll browses.
// Motion (07-MotionWallpaper): the sheet rises from below the screen, 10 px past its place and back
// (320 ms), and sinks away while fading (190 ms). Reduced motion: a 150 ms fade.
FocusScope {
    id: root

    property string screenName
    anchors.fill: parent

    readonly property bool shown: Shell.panel === "wallpaper" && (Shell.panelScreen === "" || Shell.panelScreen === screenName)
    readonly property alias body: glass
    readonly property bool active: visible

    // --- Layout (Wallpaper.dc.html): padding 20 / 22, thumbnails 14 apart, footer 16 below them,
    // 64 px from the bottom of the screen, centred, at most 1340 wide.
    readonly property real padX: Theme.px(22)
    readonly property real padY: Theme.px(20)
    readonly property real stripH: Theme.px(139)
    readonly property real footerH: Theme.px(21)
    readonly property int count: Wallpapers.items.length
    readonly property real stripNatural: Math.max(0, count - 1) * Theme.px(196 + 14) + Theme.px(244)
    readonly property real sheetW: Math.min(Theme.px(1340), width - Theme.px(80),
                                            Math.max(Theme.px(620), stripNatural + 2 * padX))
    readonly property real sheetH: padY + stripH + Theme.px(16) + footerH + padY
    readonly property real finalY: height - Theme.px(64) - sheetH

    // --- Rise / sink: p 0 = below the screen, 1 = in place.
    property real p: 0
    property bool closing: false
    visible: p > 0
    onShownChanged: {
        if (shown) forceActiveFocus()
        closing = !shown
        anim.to = shown ? 1 : 0
        anim.duration = Motion.reduced ? Motion.reducedFade : shown ? Motion.wallSheetIn : Motion.wallSheetOut
        anim.easing.type = shown || Motion.reduced ? Easing.Linear : Motion.easeClose
        anim.restart()
    }
    NumberAnimation { id: anim; target: root; property: "p" }
    readonly property real below: height + Theme.px(20)
    readonly property real sheetY: Motion.reduced ? finalY
        : closing ? below + (finalY - below) * p
        : Motion.frames(p, [[0, below], [0.8, finalY - Theme.px(10)], [1, finalY]])
    readonly property real sheetOpacity: Motion.reduced || closing ? p : Math.min(1, Motion.frames(p, [[0, 0], [0.8, 1]]))

    // Enter: the thumbnail dips, then the wallpaper ripples out of its centre.
    function applySelected() {
        const t = strip.itemAtIndex(Wallpapers.selected)?.thumb
        if (!t) return Wallpapers.apply(Qt.point(width / 2, height), screenName)
        t.press()
        Wallpapers.apply(t.mapToItem(root, t.width / 2, t.height / 2), screenName)
    }
    Connections {
        target: Wallpapers
        function onApplyRequested() { if (root.shown) root.applySelected() }
    }

    Keys.onPressed: e => {
        const k = e.key
        if (k === Qt.Key_Left || k === Qt.Key_H) Wallpapers.browse(-1)
        else if (k === Qt.Key_Right || k === Qt.Key_L) Wallpapers.browse(1)
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.applySelected()
        else if (k === Qt.Key_R) Wallpapers.random()
        else if (k === Qt.Key_Escape) Shell.close("wallpaper")   // closing reverts (Wallpapers)
        else return
        e.accepted = true
    }

    GlassRect {
        id: glass
        variant: "panel"
        radius: Theme.px(32)
        x: Math.round((root.width - width) / 2)
        y: root.sheetY
        width: root.sheetW
        height: root.sheetH
        opacity: root.sheetOpacity

        // Presses on the sheet stop here (not "outside"); scrolling browses.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            property real acc: 0
            onWheel: w => {
                acc += w.angleDelta.y !== 0 ? w.angleDelta.y : w.angleDelta.x
                while (Math.abs(acc) >= 120) {
                    Wallpapers.browse(acc > 0 ? -1 : 1)
                    acc -= Math.sign(acc) * 120
                }
            }
        }

        ListView {
            id: strip
            y: root.padY
            width: Math.min(root.stripNatural, glass.width - 2 * root.padX)
            anchors.horizontalCenter: parent.horizontalCenter
            height: root.stripH
            orientation: ListView.Horizontal
            spacing: Theme.px(14)
            interactive: false
            clip: false
            model: Wallpapers.items
            currentIndex: Wallpapers.selected
            // More wallpapers than fit: the strip scrolls to keep the selection inside.
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: Theme.px(40)
            preferredHighlightEnd: width - Theme.px(40)
            highlightMoveDuration: Motion.small
            highlightFollowsCurrentItem: false

            // ListView places delegates at y = 0; the wrapper centres the smaller thumbnails on the big one.
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property alias thumb: thumb
                width: thumb.width
                height: strip.height
                Thumb {
                    id: thumb
                    anchors.verticalCenter: parent.verticalCenter
                    item: cell.modelData
                    selected: cell.index === Wallpapers.selected
                    onClicked: selected ? root.applySelected() : Wallpapers.select(cell.index)
                }
            }
        }

        // Footer: name · palette · state … key hints (only while Alt is held).
        Item {
            x: root.padX + Theme.px(1)
            y: root.padY + root.stripH + Theme.px(16)
            width: glass.width - 2 * root.padX - Theme.px(2)
            height: root.footerH

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(10)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Wallpapers.selectedItem?.name ?? ""
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12.5)
                    font.weight: Font.DemiBold
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(5)
                    Repeater {
                        model: ["primary", "secondary", "tertiary", "surface"]
                        Rectangle {
                            required property string modelData
                            width: Theme.px(18)
                            height: width
                            radius: width / 2
                            color: Wallpapers.selectedPalette?.[modelData] ?? "transparent"
                            border.width: 1
                            border.color: Theme.white(0.25)
                            Behavior on color { ColorAnimation { duration: Motion.themeFade } }
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Wallpapers.selected === Wallpapers.appliedIndex ? "current" : "previewing live"
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12.5)
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(8)
                opacity: KeyHints.held ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.micro } }
                Repeater {
                    model: [["← →", "browse"], ["Enter", "apply"], ["R", "random"], ["Esc", "revert"]]
                    Row {
                        required property var modelData
                        required property int index
                        spacing: Theme.px(8)
                        leftPadding: index > 0 ? Theme.px(6) : 0
                        KeyHint { anchors.verticalCenter: parent.verticalCenter; key: modelData[0] }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData[1]
                            color: Theme.textMuted
                            font.family: Theme.font
                            font.pixelSize: Theme.px(12.5)
                        }
                    }
                }
            }
        }
    }
}
