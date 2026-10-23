import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// Phase 1 test surface: `qs ipc call test toggle`. Shows a panel, a dialog and the pill states from the
// bottom row of design/screens/10-Popovers.jpg, at the same design positions. The "Rest" pill is live
// (hover / press it). Switch strength with `qs ipc call glass set heavy`; hold Alt for key hints.
PanelWindow {
    id: win

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "glass-shell-test"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // Clicks only land on the test content; everything else passes through to the windows below.
    mask: Region {
        Region { item: panel }
        Region { item: dialog }
        Region { item: states }
    }

    component Label: Text {
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.px(12)
    }

    // The clock pill used for every state: "Tue 20 Oct" muted + "06:47" 600, padding 14, gap 10.
    component ClockPill: GlassRect {
        id: pill
        implicitWidth: row.implicitWidth + Theme.px(28)
        implicitHeight: Theme.px(38)
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.px(10)
            Text {
                anchors.baseline: time.baseline
                text: "Tue 20 Oct"
                color: pill.lit ? Theme.textOnContainer : pill.hovered ? Qt.tint(Theme.textMuted, Theme.white(0.3)) : Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.px(13)
            }
            Text {
                id: time
                text: "06:47"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.px(14)
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
    }

    component State: ColumnLayout {
        property alias label: l.text
        property alias pill: p
        property bool hovered
        property bool pressed
        property bool lit
        property bool focused
        property bool disabled
        spacing: Theme.px(10)
        ClockPill {
            id: p
            Layout.alignment: Qt.AlignHCenter
            hovered: parent.hovered; pressed: parent.pressed; lit: parent.lit
            focused: parent.focused; enabled: !parent.disabled
        }
        Label { id: l; Layout.alignment: Qt.AlignHCenter }
    }

    // --- Panel (Control Center / launcher / popover material)
    GlassRect {
        id: panel
        variant: "panel"
        x: Theme.px(24); y: Theme.px(100)
        width: Theme.px(410); height: Theme.px(300)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.px(16)
            spacing: Theme.px(10)
            Text {
                text: "Panel"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.px(15)
                font.weight: Font.DemiBold
            }
            Text {
                text: "SECTION LABEL"
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.px(11.5)
                font.letterSpacing: Theme.px(0.6)
            }
            Repeater {
                model: [["Wi-Fi", "W"], ["Bluetooth", "B"], ["Night light", "1"]]
                GlassRect {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(44)
                    radius: Theme.px(14)
                    lit: index === 0
                    hovered: rowMouse.containsMouse
                    pressed: rowMouse.pressed
                    MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(14)
                        anchors.rightMargin: Theme.px(10)
                        Text {
                            Layout.fillWidth: true
                            text: modelData[0]
                            color: parent.parent.lit ? Theme.textOnContainer : Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.px(13.5)
                        }
                        KeyHint { key: modelData[1] }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    // --- Dialog (polkit material)
    GlassRect {
        id: dialog
        variant: "dialog"
        x: Theme.px(480); y: Theme.px(100)
        width: Theme.px(460); height: Theme.px(300)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.px(24)
            spacing: Theme.px(10)
            Text {
                text: "Authentication required"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.px(17)
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Glass strength: " + Config.glass + ". Reduced motion: " + (Config.reducedMotion ? "on" : "off") + "."
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.px(13)
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Theme.px(10)
                Repeater {
                    model: [["Cancel", "Esc", false], ["Authenticate", "↵", true]]
                    GlassRect {
                        id: btn
                        required property var modelData
                        implicitWidth: btnRow.implicitWidth + Theme.px(32)
                        implicitHeight: Theme.px(40)
                        lit: modelData[2]
                        hovered: btnMouse.containsMouse
                        pressed: btnMouse.pressed
                        MouseArea { id: btnMouse; anchors.fill: parent; hoverEnabled: true }
                        Row {
                            id: btnRow
                            anchors.centerIn: parent
                            spacing: Theme.px(8)
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: btn.modelData[0]
                                color: btn.lit ? Theme.textOnContainer : Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.px(13)
                                font.weight: Font.Medium
                            }
                            KeyHint { anchors.verticalCenter: parent.verticalCenter; key: btn.modelData[1] }
                        }
                    }
                }
            }
        }
    }

    // --- Pill states (10-Popovers bottom row: left 24, top 580/624, gap 46)
    Text {
        x: Theme.px(24); y: Theme.px(580)
        text: "Every pill, button and tile reacts the same way"
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.px(13.5)
        font.weight: Font.DemiBold
    }
    RowLayout {
        id: states
        x: Theme.px(24); y: Theme.px(624)
        spacing: Theme.px(46)

        State {
            id: rest
            label: "Rest"
            hovered: restMouse.containsMouse
            pressed: restMouse.pressed
            MouseArea { id: restMouse; parent: rest.pill; anchors.fill: parent; hoverEnabled: true }
        }
        State { label: "Hover · lighter, +4 %, 120 ms"; hovered: true }
        State { label: "Press · squish to 95 %"; pressed: true }
        State { label: "Open · its panel is showing"; lit: true }
        State { label: "Keyboard focus ring"; focused: true }
        State { label: "Disabled"; disabled: true }
    }
}
