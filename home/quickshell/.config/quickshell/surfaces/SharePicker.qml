import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components
import "../components/apps.js" as Apps

// Screen-share picker (DESIGN.md §3.7, 25-SharePicker; values from SharePicker.dc.html), driven by Share.qml.
// Dim + blur, then a 1000 px sheet (radius 30) rises from 92 %: the app's icon and "<App> wants to share your
// screen", Screen / Window / Region tabs, a 3-column grid of live thumbnails (1–9), "Remember for <app>" (only
// when the app asked to be remembered), Cancel / Share. Keys: Tab tabs · 1–9 or arrows pick · Enter share ·
// Esc cancel. Region hands over to the capture tool's region selection.
Scope {
    id: root

    required property ShellScreen screen

    readonly property bool shown: Share.asking && screen === (Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0])

    PanelWindow {
        id: win

        screen: root.screen
        visible: root.shown || anim.running
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glass-shell-share"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        // Rise: the dim + blur first (200 ms), then the sheet scales in from 92 %.
        property real p: 0
        NumberAnimation on p { id: anim; running: false }
        Connections {
            target: root
            function onShownChanged() {
                anim.stop()
                anim.to = root.shown ? 1 : 0
                anim.duration = root.shown ? Motion.open(Motion.captureDim + 260) : Motion.close(Motion.medium)
                anim.easing.type = root.shown ? Easing.Linear : Motion.easeClose
                anim.start()
                if (root.shown) keys.forceActiveFocus()
            }
        }
        readonly property real dimP: Math.min(1, p * 2)
        readonly property real sheetP: Math.max(0, p * 2 - 1)

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true
            // Gone at once when Region hands over to the capture tool (it freezes the screen).
            opacity: Capture.hiding ? 0 : 1

            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.scrim, 0.5)
                opacity: win.dimP
                // A click outside cancels.
                MouseArea { anchors.fill: parent; onClicked: Share.cancel() }
            }

            Keys.onPressed: e => {
                const k = e.key
                if (k === Qt.Key_Escape) Share.cancel()
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) Share.share()
                else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) Share.nextTab()
                else if (k === Qt.Key_Left || k === Qt.Key_H) Share.move(-1)
                else if (k === Qt.Key_Right || k === Qt.Key_L) Share.move(1)
                else if (k === Qt.Key_Up || k === Qt.Key_K) Share.move(-3)
                else if (k === Qt.Key_Down || k === Qt.Key_J) Share.move(3)
                else if (k >= Qt.Key_1 && k <= Qt.Key_9 && k - Qt.Key_1 < Share.count) Share.selected = k - Qt.Key_1
                else if (k === Qt.Key_Space && Share.tokenAllowed) Share.remember = !Share.remember
                else return
                e.accepted = true
            }

            GlassRect {
                id: sheet
                variant: "dialog"
                radius: Theme.px(30)
                width: Theme.px(1000)
                height: col.implicitHeight + Theme.px(40)
                x: Math.round((parent.width - width) / 2)
                y: Theme.px(110)
                scale: Motion.reduced ? 1 : 0.92 + 0.08 * win.sheetP
                opacity: win.sheetP

                MouseArea { anchors.fill: parent }

                Column {
                    id: col
                    x: Theme.px(20)
                    y: Theme.px(20)
                    width: parent.width - Theme.px(40)
                    spacing: Theme.px(20)

                    // --- Header: app icon, question, tabs
                    Item {
                        width: parent.width
                        height: Theme.px(44)
                        Rectangle {
                            id: appTile
                            width: Theme.px(44)
                            height: width
                            radius: Theme.px(14)
                            color: Theme.secondaryContainer
                            Icon {
                                anchors.centerIn: parent
                                name: Apps.iconFor(Share.appClass)
                                size: Theme.px(20)
                                color: Theme.text
                            }
                        }
                        Column {
                            anchors.left: appTile.right
                            anchors.leftMargin: Theme.px(14)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(2)
                            Text {
                                text: `${Share.app} wants to share your screen`
                                font.family: Theme.font
                                font.pixelSize: Theme.px(18)
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }
                            Text {
                                text: Share.tab === "region" ? "Draw the part people in the call will see" : "Pick what people in the call will see"
                                font.family: Theme.font
                                font.pixelSize: Theme.px(13)
                                color: Theme.textMuted
                            }
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: tabs.implicitWidth + Theme.px(6)
                            height: Theme.px(38)
                            radius: height / 2
                            color: Theme.white(0.07)
                            Row {
                                id: tabs
                                anchors.centerIn: parent
                                Repeater {
                                    model: [["screen", "Screen"], ["window", "Window"], ["region", "Region"]]
                                    Button {
                                        id: tabBtn
                                        required property var modelData
                                        readonly property bool on: Share.tab === modelData[0]
                                        width: tabText.implicitWidth + Theme.px(32)
                                        height: Theme.px(32)
                                        hoverScale: 1
                                        lit: on
                                        litColor: Theme.white(0.16)
                                        onClicked: Share.setTab(modelData[0])
                                        Text {
                                            id: tabText
                                            anchors.centerIn: parent
                                            text: tabBtn.modelData[1]
                                            font.family: Theme.font
                                            font.pixelSize: Theme.px(13)
                                            font.weight: tabBtn.on ? Font.DemiBold : Font.Normal
                                            color: tabBtn.on ? Theme.text : Theme.textMuted
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // --- Thumbnails (Screen / Window) or the Region hint
                    Grid {
                        visible: Share.tab !== "region"
                        width: parent.width
                        columns: 3
                        columnSpacing: Theme.px(18)
                        rowSpacing: Theme.px(18)
                        Repeater {
                            model: Share.tab === "window" ? Share.windows : Share.tab === "screen" ? Share.screens : []
                            Thumb {
                                required property var modelData
                                required property int index
                                width: (col.width - 2 * Theme.px(18)) / 3
                                number: index + 1
                                selected: Share.selected === index
                                source: Share.tab === "window" ? (modelData.toplevel?.wayland ?? null) : modelData
                                whole: Share.tab === "screen"
                                name: Share.tab === "window" ? (modelData.title || modelData.cls) : modelData.name
                                detail: Share.tab === "window"
                                    ? (/steam_app|gamescope/.test(modelData.cls) || modelData.cls === "" ? "workspace " + modelData.workspace : Apps.iconFor(modelData.cls) === "app-window" ? modelData.cls : root.nice(modelData.cls))
                                    : `${modelData.width} × ${modelData.height}`
                                onPicked: { Share.selected = index; Share.share() }
                                onChosen: Share.selected = index
                            }
                        }
                    }
                    Rectangle {
                        visible: Share.tab === "region"
                        width: parent.width
                        height: Theme.px(118)
                        radius: Theme.px(14)
                        color: Theme.white(0.05)
                        border.width: Theme.px(1.5)
                        border.color: Theme.alpha(Theme.accent, 0.6)
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.px(8)
                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "crop"
                                size: Theme.px(22)
                                color: Theme.accent
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Share opens the region tool: drag the part to share, then Enter"
                                font.family: Theme.font
                                font.pixelSize: Theme.px(13)
                                color: Theme.textMuted
                            }
                        }
                    }

                    // --- Footer: remember · Cancel / Share
                    Item {
                        width: parent.width
                        height: Theme.px(42)
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(8)
                            // Only an app that asked to be remembered can be (xdph's restore token).
                            enabled: Share.tokenAllowed
                            opacity: enabled ? 1 : 0.45
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(18)
                                height: width
                                radius: Theme.px(5)
                                color: Share.remember ? Theme.accent : "transparent"
                                border.width: Share.remember ? 0 : Theme.px(1.5)
                                border.color: Theme.white(0.4)
                                Icon {
                                    anchors.centerIn: parent
                                    visible: Share.remember
                                    name: "check"
                                    size: Theme.px(13)
                                    strokeWidth: 3
                                    color: Theme.textOnAccent
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Remember for " + Share.app
                                font.family: Theme.font
                                font.pixelSize: Theme.px(13)
                                color: Theme.text
                            }
                            KeyHint { anchors.verticalCenter: parent.verticalCenter; key: "Space" }
                        }
                        MouseArea {
                            width: Theme.px(220)
                            height: parent.height
                            enabled: Share.tokenAllowed
                            onClicked: Share.remember = !Share.remember
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(12)
                            Button {
                                width: cancelRow.implicitWidth + Theme.px(40)
                                height: Theme.px(42)
                                base: Theme.white(0.1)
                                onClicked: Share.cancel()
                                Row {
                                    id: cancelRow
                                    anchors.centerIn: parent
                                    spacing: Theme.px(8)
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Cancel"
                                        font.family: Theme.font
                                        font.pixelSize: Theme.px(14)
                                        color: Theme.text
                                    }
                                    KeyHint { anchors.verticalCenter: parent.verticalCenter; key: "Esc" }
                                }
                            }
                            Button {
                                width: shareRow.implicitWidth + Theme.px(44)
                                height: Theme.px(42)
                                base: Theme.accent
                                enabled: Share.tab === "region" || Share.count > 0
                                onClicked: Share.share()
                                Row {
                                    id: shareRow
                                    anchors.centerIn: parent
                                    spacing: Theme.px(8)
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Share"
                                        font.family: Theme.font
                                        font.pixelSize: Theme.px(14)
                                        font.weight: Font.DemiBold
                                        color: Theme.textOnAccent
                                    }
                                    KeyHint { anchors.verticalCenter: parent.verticalCenter; key: "Enter"; ink: Theme.textOnAccent }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function nice(cls: string): string {
        const c = (cls || "").split(".").pop()
        return c.charAt(0).toUpperCase() + c.slice(1)
    }

    // A thumbnail: the wallpaper with the live window (or the whole screen) on it, number cap, caption.
    component Thumb: Column {
        id: thumb
        property int number
        property bool selected
        property var source: null
        property bool whole: false
        property string name
        property string detail
        signal picked()
        signal chosen()
        spacing: Theme.px(8)

        Item {
            width: thumb.width
            height: Theme.px(118)
            // Selected: 3 px accent ring outside the card.
            Rectangle {
                anchors.fill: parent
                anchors.margins: -Theme.px(3)
                radius: Theme.px(17)
                color: "transparent"
                border.width: Theme.px(3)
                border.color: Theme.accent
                visible: thumb.selected
            }
            ClippingRectangle {
                anchors.fill: parent
                radius: Theme.px(14)
                color: Theme.glassTint
                border.width: 1
                border.color: Theme.white(0.12)
                Image {
                    anchors.fill: parent
                    visible: !thumb.whole
                    source: Theme.wallpaper !== "" ? "file://" + Theme.wallpaper : ""
                    sourceSize.width: Theme.px(320)
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.75
                    asynchronous: true
                }
                // Live picture: a window sits inset like on a desktop; a screen fills the card.
                ClippingRectangle {
                    x: thumb.whole ? 0 : Theme.px(16)
                    y: thumb.whole ? 0 : Theme.px(14)
                    width: parent.width - 2 * x
                    height: parent.height - y
                    topLeftRadius: thumb.whole ? 0 : Theme.px(6)
                    topRightRadius: thumb.whole ? 0 : Theme.px(6)
                    color: Theme.white(0.06)
                    ScreencopyView {
                        anchors.fill: parent
                        captureSource: root.shown ? thumb.source : null
                        live: true
                        constraintSize: Qt.size(width * 1.5, height * 1.5)
                    }
                }
                Rectangle {
                    x: Theme.px(8)
                    y: Theme.px(8)
                    width: Theme.px(20)
                    height: width
                    radius: Theme.px(6)
                    color: Qt.rgba(0, 0, 0, 0.5)
                    border.width: 1
                    border.color: Theme.white(0.25)
                    visible: thumb.number <= 9
                    opacity: KeyHints.held ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.micro } }
                    Text {
                        anchors.centerIn: parent
                        text: thumb.number
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.px(11)
                        color: Theme.text
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: thumb.chosen()
                onDoubleClicked: thumb.picked()
            }
        }
        Row {
            width: thumb.width
            spacing: Theme.px(4)
            Text {
                text: thumb.name
                elide: Text.ElideRight
                width: Math.min(implicitWidth, thumb.width * 0.7)
                font.family: Theme.font
                font.pixelSize: Theme.px(12.5)
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                text: "· " + thumb.detail
                elide: Text.ElideRight
                width: Math.min(implicitWidth, thumb.width * 0.3)
                font.family: Theme.font
                font.pixelSize: Theme.px(12.5)
                color: Theme.textFaint
            }
        }
    }
}
