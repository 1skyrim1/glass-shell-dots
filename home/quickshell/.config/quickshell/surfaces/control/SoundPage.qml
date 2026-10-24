import QtQuick
import Quickshell.Services.Pipewire
import qs.services
import qs.components
import qs.surfaces.launcher

// Sound (17-ControlPages): outputs and inputs (the default one tinted; the default mic with its live
// level), then the volume of every app playing. Enter / click picks a device; ← → change the volume of
// the row the keys are on, M mutes it.
Column {
    id: root

    property Item cc

    // Rows the keys move over: outputs, inputs, apps.
    readonly property var entries: Audio.sinks.concat(Audio.sources, Audio.streams)
    property int cursor: Math.max(0, entries.indexOf(Audio.sink))
    readonly property var current: entries[Math.min(cursor, entries.length - 1)] ?? null

    function key(e: var): bool {
        const k = e.key, n = entries.length
        if (k === Qt.Key_J || k === Qt.Key_Down || k === Qt.Key_Tab) { cursor = (cursor + 1) % Math.max(1, n); return true }
        if (k === Qt.Key_K || k === Qt.Key_Up || k === Qt.Key_Backtab) { cursor = (cursor - 1 + n) % Math.max(1, n); return true }
        if (!current) return false
        if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_H || k === Qt.Key_L) {
            const d = k === Qt.Key_Left || k === Qt.Key_H ? -1 : 1
            Audio.setVolume(current, (current.audio?.volume ?? 0) + d * Audio.step)
            return true
        }
        if (k === Qt.Key_M) { Audio.toggleNodeMute(current); return true }
        if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && !current.isStream) { Audio.setDefault(current); return true }
        return false
    }

    // Volumes of every node are only tracked while this page shows; the mic level likewise.
    Binding { target: Audio; property: "watching"; value: root.visible }
    // The level is measured above the mic's noise floor (which drops at once and creeps back up), so the
    // bars stay dark in a quiet room even with a high capture gain.
    PwNodePeakMonitor {
        id: peak
        node: Audio.source
        enabled: root.visible
        property real floor: 1
        property real level: 0
        onPeakChanged: {
            floor = peak.peak < floor ? peak.peak : floor + 0.002
            level = Math.max(0, Math.min(1, (peak.peak - floor) * 4))
        }
    }

    PageHeader {
        title: "Sound"
        onBack: Shell.controlPage = ""
    }

    component DeviceRow: ListRow {
        required property var modelData
        width: root.width
        icon: Audio.iconOf(modelData)
        text: Audio.nameOf(modelData)
        note: Audio.noteOf(modelData)
        focused: root.current === modelData
        onClicked: { root.cursor = root.entries.indexOf(modelData); Audio.setDefault(modelData) }
    }

    SectionLabel { text: "Output"; above: Theme.px(12); below: Theme.px(6); leftPadding: Theme.px(4) }
    Repeater {
        model: Audio.sinks
        DeviceRow { selected: modelData === Audio.sink }
    }

    SectionLabel { text: "Input"; above: Theme.px(12); below: Theme.px(6); leftPadding: Theme.px(4) }
    Repeater {
        model: Audio.sources
        DeviceRow {
            id: input
            readonly property bool isDefault: modelData === Audio.source
            selected: isDefault
            note: isDefault ? "" : Audio.noteOf(modelData)
            // Live level: four bars, lit (good) up to the current peak.
            Row {
                visible: input.isDefault
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.px(14)
                spacing: Theme.px(2)
                Repeater {
                    model: [5, 9, 13, 7]
                    Rectangle {
                        required property int modelData
                        required property int index
                        anchors.bottom: parent.bottom
                        width: Theme.px(3)
                        height: Theme.px(modelData)
                        radius: Theme.px(1)
                        readonly property bool lit: !Audio.micMuted && peak.level > [0.05, 0.25, 0.5, 0.75][index]
                        color: lit ? Theme.good : Theme.white(0.2)
                    }
                }
            }
        }
    }

    SectionLabel {
        visible: Audio.streams.length > 0
        text: "Apps"
        above: Theme.px(12)
        below: Theme.px(6)
        leftPadding: Theme.px(4)
    }
    Repeater {
        model: Audio.streams
        Button {
            id: app
            required property var modelData
            readonly property bool muted: modelData.audio?.muted ?? false
            width: root.width
            height: Theme.px(44)
            radius: Theme.px(12)
            hoverScale: 1
            squish: 1
            focused: root.current === modelData
            onClicked: root.cursor = root.entries.indexOf(modelData)
            Text {
                id: appName
                x: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(70)
                text: Audio.nameOf(app.modelData)
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.px(13)
                elide: Text.ElideRight
            }
            Slider {
                anchors { left: appName.right; leftMargin: Theme.px(12); right: app.muted ? mutedNote.left : parent.right; rightMargin: Theme.px(12); verticalCenter: parent.verticalCenter }
                value: app.modelData.audio?.volume ?? 0
                fill: app.muted ? Theme.white(0.35) : Theme.accent
                onMoved: v => Audio.setVolume(app.modelData, v)
            }
            Text {
                id: mutedNote
                anchors { right: parent.right; rightMargin: Theme.px(12); verticalCenter: parent.verticalCenter }
                visible: app.muted
                text: "muted"
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.px(11.5)
                MouseArea { anchors.fill: parent; anchors.margins: -Theme.px(6); onClicked: Audio.toggleNodeMute(app.modelData) }
            }
        }
    }

    HintBar {
        above: Theme.px(10)
        hints: [["J K", "move"], ["← →", "volume"], ["M", "mute"], ["Esc", "back"]]
    }
}
