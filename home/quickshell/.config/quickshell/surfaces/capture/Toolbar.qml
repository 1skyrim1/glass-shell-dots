import QtQuick
import qs.services
import qs.components

// The capture toolbar (21-CaptureRegion, 22-CaptureWindow; values from CaptureRegion / CaptureWindow.dc.html):
// 74 px, radius 37. Region / Window / Screen (R W S) · screenshot ↔ record (Tab; V in Window mode, where Tab
// picks the next window) · photo: Delay (D) and Copy + save (O) · video: Mic (M), Desktop audio (A), Cursor (C),
// fps · format (F) · Capture / red Start (Enter) · × (Esc). The keys themselves are handled by the surface.
GlassRect {
    id: root

    variant: "popover"
    implicitWidth: row.implicitWidth + Theme.px(18)
    implicitHeight: Theme.px(74)
    radius: height / 2

    readonly property bool video: Capture.kind === "video"

    // Presses on the toolbar stop here.
    MouseArea { anchors.fill: parent }

    Row {
        id: row
        x: Theme.px(9)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(4)

        // --- Target
        Repeater {
            model: [["region", "crop", "Region", "R"], ["window", "window", "Window", "W"], ["screen", "monitor", "Screen", "S"]]
            Button {
                id: seg
                required property var modelData
                readonly property bool on: Capture.mode === modelData[0]
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(Theme.px(70), segLabel.implicitWidth + Theme.px(8))
                height: Theme.px(56)
                radius: Theme.px(16)
                lit: on
                litColor: Theme.accent
                onClicked: Capture.setMode(modelData[0])
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.px(3)
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: seg.modelData[1]
                        size: Theme.px(17)
                        color: seg.on ? Theme.textOnAccent : Theme.textMuted
                    }
                    Row {
                        id: segLabel
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.px(4)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: seg.modelData[2]
                            font.family: Theme.font
                            font.pixelSize: Theme.px(11.5)
                            font.weight: seg.on ? Font.DemiBold : Font.Normal
                            color: seg.on ? Theme.textOnAccent : Theme.textMuted
                        }
                        KeyHint {
                            anchors.verticalCenter: parent.verticalCenter
                            key: seg.modelData[3]
                            ink: seg.on ? Theme.textOnAccent : "transparent"
                        }
                    }
                }
            }
        }

        Sep {}

        // --- Screenshot ↔ record
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: kinds.implicitWidth + Theme.px(8)
            height: Theme.px(48)
            radius: Theme.px(20)
            color: Theme.white(0.07)
            Row {
                id: kinds
                anchors.centerIn: parent
                spacing: Theme.px(2)
                Repeater {
                    model: [["photo", "camera"], ["video", "video"]]
                    Button {
                        id: kindBtn
                        required property var modelData
                        readonly property bool on: Capture.kind === modelData[0]
                        width: Theme.px(46)
                        height: Theme.px(40)
                        radius: Theme.px(16)
                        lit: on
                        litColor: modelData[0] === "video" ? Theme.alpha(Theme.error, 0.3) : Theme.white(0.18)
                        onClicked: Capture.kind = modelData[0]
                        Icon {
                            anchors.centerIn: parent
                            name: kindBtn.modelData[1]
                            size: Theme.px(17)
                            color: !kindBtn.on ? Theme.textMuted : kindBtn.modelData[0] === "video" ? Theme.textOnError : Theme.text
                        }
                    }
                }
            }
        }
        KeyHint {
            anchors.verticalCenter: parent.verticalCenter
            key: "Tab"
            visible: opacity > 0 && Capture.mode !== "window"
        }

        Sep {}

        // --- Photo options: delay and where it goes
        Column {
            visible: !root.video
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Theme.px(8)
            rightPadding: Theme.px(8)
            spacing: Theme.px(3)
            OptLine {
                label: "Delay"
                value: Capture.delay === 0 ? "off" : Capture.delay + " s"
                key: "D"
                onClicked: Capture.cycleDelay()
            }
            OptLine {
                label: Capture.outputNames[Capture.output]
                key: "O"
                onClicked: Capture.cycleOutput()
            }
        }

        // --- Record options: 2 × 2, on = accent 18 %
        Grid {
            visible: root.video
            anchors.verticalCenter: parent.verticalCenter
            columns: 2
            rowSpacing: Theme.px(2)
            columnSpacing: Theme.px(4)
            Opt { icon: "mic"; label: "Mic"; key: "M"; on: Capture.mic; onClicked: Capture.mic = !Capture.mic }
            Opt { icon: "volume"; label: "Desktop audio"; key: "A"; on: Capture.desktopAudio; onClicked: Capture.desktopAudio = !Capture.desktopAudio }
            Opt { icon: "pointer"; label: "Cursor"; key: "C"; on: Capture.cursor; onClicked: Capture.cursor = !Capture.cursor }
            Opt { label: Capture.fps + " fps · " + Capture.format; mono: true; key: "F"; on: false; onClicked: Capture.cycleFormat() }
        }

        Sep {}

        // --- Capture / Start
        Button {
            id: go
            anchors.verticalCenter: parent.verticalCenter
            width: goRow.implicitWidth + Theme.px(36)
            height: Theme.px(50)
            base: root.video ? Theme.error : Theme.accent
            readonly property color ink: root.video ? Theme.textOnErrorStrong : Theme.textOnAccent
            onClicked: Capture.capture()
            Row {
                id: goRow
                anchors.centerIn: parent
                spacing: Theme.px(10)
                Rectangle {
                    visible: root.video
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(10)
                    height: width
                    radius: width / 2
                    color: go.ink
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Capture.forShare ? "Share" : root.video ? "Start" : "Capture"
                    font.family: Theme.font
                    font.pixelSize: Theme.px(13.5)
                    font.weight: Font.DemiBold
                    color: go.ink
                }
                KeyHint {
                    anchors.verticalCenter: parent.verticalCenter
                    key: "Enter"
                    ink: go.ink
                }
            }
        }

        // --- ×
        Item {
            width: Theme.px(44)
            height: Theme.px(40)
            anchors.verticalCenter: parent.verticalCenter
            Button {
                anchors.right: parent.right
                width: Theme.px(40)
                height: width
                onClicked: Capture.close()
                Icon {
                    anchors.centerIn: parent
                    name: "x"
                    size: Theme.px(17)
                    strokeWidth: 2.2
                    color: Theme.textMuted
                }
            }
        }
    }

    component Sep: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1 + Theme.px(12)
        height: Theme.px(36)
        color: "transparent"
        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: parent.height
            color: Theme.white(0.14)
        }
    }

    // "Delay off [D]": label, bold value, key cap; click cycles.
    component OptLine: Item {
        id: line
        property string label
        property string value: ""
        property string key
        signal clicked()
        implicitWidth: lineRow.implicitWidth
        implicitHeight: lineRow.implicitHeight
        Row {
            id: lineRow
            spacing: Theme.px(4)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: line.label
                font.family: Theme.font
                font.pixelSize: Theme.px(11.5)
                color: Theme.textMuted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: line.value !== ""
                text: line.value
                font.family: Theme.font
                font.pixelSize: Theme.px(11.5)
                font.weight: Font.DemiBold
                color: Theme.text
            }
            KeyHint {
                anchors.verticalCenter: parent.verticalCenter
                key: line.key
            }
        }
        MouseArea { anchors.fill: parent; onClicked: line.clicked() }
    }

    // A record option (CaptureWindow.dc.html .opt): 30 px, radius 15, accent 18 % while on.
    component Opt: Button {
        id: opt
        property string icon: ""
        property string label
        property string key
        property bool on
        property bool mono: false
        hoverScale: 1
        width: Math.max(Theme.px(122), optRow.implicitWidth + Theme.px(20))
        height: Theme.px(30)
        lit: on
        litColor: Theme.alpha(Theme.accent, 0.18)
        Row {
            id: optRow
            x: Theme.px(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(7)
            Icon {
                visible: opt.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: opt.icon
                size: Theme.px(15)
                color: opt.on ? Theme.text : Theme.textMuted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: opt.label
                font.family: opt.mono ? Theme.fontMono : Theme.font
                font.pixelSize: Theme.px(12)
                color: opt.on ? Theme.text : Theme.textMuted
            }
            KeyHint {
                anchors.verticalCenter: parent.verticalCenter
                key: opt.key
            }
        }
    }
}
