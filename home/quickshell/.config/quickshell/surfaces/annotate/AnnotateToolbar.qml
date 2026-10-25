import QtQuick
import qs.services
import qs.components

// Annotate's bottom toolbar (23-Annotate; Annotate.dc.html): 64 px, radius 32. Eight tools (44 px, radius 14,
// the key in the corner while Alt is held) · five colours · three stroke sizes · undo / redo.
GlassRect {
    id: root

    required property var editor   // Annotate.qml's editor state (tool, colour, stroke, undo / redo)

    variant: "popover"
    implicitWidth: row.implicitWidth + Theme.px(20)
    implicitHeight: Theme.px(64)
    radius: height / 2

    MouseArea { anchors.fill: parent }

    Row {
        id: row
        x: Theme.px(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(4)

        Repeater {
            model: [["select", "pointer", "V"], ["arrow", "arrow", "A"], ["rect", "rectangle", "R"], ["pen", "pen", "P"],
                    ["text", "type", "T"], ["highlight", "highlighter", "H"], ["blur", "pixelate", "B"], ["crop", "crop", "C"]]
            Button {
                id: tool
                required property var modelData
                readonly property bool on: root.editor.tool === modelData[0]
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(44)
                height: width
                radius: Theme.px(14)
                lit: on
                litColor: Theme.accent
                onClicked: root.editor.setTool(modelData[0])
                Icon {
                    anchors.centerIn: parent
                    name: tool.modelData[1]
                    size: Theme.px(18)
                    color: tool.on ? Theme.textOnAccent : Theme.textMuted
                }
                Text {
                    anchors { right: parent.right; bottom: parent.bottom; rightMargin: Theme.px(4); bottomMargin: Theme.px(2) }
                    text: tool.modelData[2]
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.px(9)
                    color: tool.on ? Theme.textOnAccent : Theme.textMuted
                    opacity: KeyHints.held ? 0.75 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
                }
            }
        }

        Sep {}

        // Colours: accent, red, yellow, white, black (1–5); the chosen one gets a dark gap + white ring.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Theme.px(6)
            rightPadding: Theme.px(6)
            spacing: Theme.px(8)
            Repeater {
                model: root.editor.colors
                Item {
                    id: sw
                    required property color modelData
                    required property int index
                    readonly property bool on: root.editor.colorIndex === index
                    width: Theme.px(22)
                    height: width
                    Rectangle {
                        anchors.centerIn: parent
                        visible: sw.on
                        width: parent.width + Theme.px(8)
                        height: width
                        radius: width / 2
                        color: Theme.markWhite
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        visible: sw.on
                        width: parent.width + Theme.px(4)
                        height: width
                        radius: width / 2
                        color: Theme.glassTint
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: sw.modelData
                        border.width: sw.index === 4 ? Theme.px(1.5) : 0
                        border.color: Theme.white(0.4)
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Theme.px(3)
                        onClicked: root.editor.setColor(sw.index)
                    }
                }
            }
        }

        Sep {}

        // Stroke sizes ([ ]): dots of 4 / 8 / 12 px; the chosen one is accent with a soft ring.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Theme.px(6)
            rightPadding: Theme.px(6)
            spacing: Theme.px(6)
            Repeater {
                model: 3
                Item {
                    id: dot
                    required property int index
                    readonly property bool on: root.editor.stroke === index
                    width: Theme.px(12)
                    height: Theme.px(22)
                    // Soft 4 px ring around the chosen one (outside the dot, like a box-shadow spread).
                    Rectangle {
                        anchors.centerIn: parent
                        visible: dot.on
                        width: Theme.px(4 + 4 * dot.index + 8)
                        height: width
                        radius: width / 2
                        color: Theme.alpha(Theme.accent, 0.25)
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.px(4 + 4 * dot.index)
                        height: width
                        radius: width / 2
                        color: dot.on ? Theme.accent : Theme.textMuted
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Theme.px(3)
                        onClicked: root.editor.stroke = dot.index
                    }
                }
            }
        }

        Sep {}

        Button {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(44)
            height: width
            radius: Theme.px(14)
            enabled: root.editor.canUndo
            onClicked: root.editor.undo()
            Icon { anchors.centerIn: parent; name: "undo"; size: Theme.px(18); color: Theme.textMuted }
        }
        Button {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(44)
            height: width
            radius: Theme.px(14)
            enabled: root.editor.canRedo
            onClicked: root.editor.redo()
            Icon { anchors.centerIn: parent; name: "redo"; size: Theme.px(18); color: Theme.textMuted }
        }
    }

    component Sep: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1 + Theme.px(8)
        height: Theme.px(28)
        color: "transparent"
        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: parent.height
            color: Theme.white(0.14)
        }
    }
}
