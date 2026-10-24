import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.components

// What capture leaves behind (DESIGN.md §3.7):
// - Shot card (21-CaptureRegion, bottom-left, 6 s): the thumbnail the selection flew into, "Copied to clipboard",
//   Annotate E · Save as S · Delete X; click opens Annotate. While it shows it holds the keyboard, so those keys
//   work straight after the shot; any other key (or Esc) puts it away. Save as turns the action line into a path
//   field (Enter saves, Esc cancels).
// - Recording card (24-CaptureExtras "Recording done · trim"): drops out of the red pill as it merges back into
//   the clock. Thumbnail + duration, folder · size, Copy / Open folder / Trim. Trim opens the filmstrip under it:
//   ← → (or , .) move the start / end, Tab switches between them, Enter saves a trimmed copy next to the original.
// Own Top layer (above windows, like toasts); glass, so its namespace starts with "glass-shell-".
Scope {
    id: root

    required property ShellScreen screen

    readonly property bool here: Capture.monitor.name === screen.name || (Capture.monitor.name === "" && screen === Quickshell.screens[0])
    readonly property bool shotUp: here && Capture.cardShown && Capture.lastShot !== "" && Capture.phase === ""
    readonly property bool recUp: here && Recorder.cardShown && Recorder.saved !== null
    readonly property bool trimming: recUp && Recorder.trim !== ""

    PanelWindow {
        id: win

        screen: root.screen
        visible: shot.p > 0 || rec.p > 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "glass-shell-capturecard"
        // Never while the capture tool or Annotate is up: they hold the keyboard then.
        WlrLayershell.keyboardFocus: (root.shotUp || root.trimming) && !Capture.active && Capture.annotating === ""
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        mask: Region {
            Region { item: shot.p > 0 ? shot : null }
            Region { item: rec.p > 0 ? rec : null }
            Region { item: strip.visible ? strip : null }
        }

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true
            Connections {
                target: root
                function onShotUpChanged() { if (root.shotUp) { shot.saving = false; keys.forceActiveFocus() } }
                function onTrimmingChanged() { if (root.trimming) keys.forceActiveFocus() }
            }

            // Keys act on release (the layer lets go of the keyboard as the card leaves).
            property int armed: 0
            Keys.onPressed: e => {
                if (!e.isAutoRepeat) armed = e.key
                e.accepted = true
                if (root.trimming && Recorder.trim === "open") {
                    const k = e.key, step = e.modifiers & Qt.ShiftModifier ? 0.1 : 1
                    if (k === Qt.Key_Left || k === Qt.Key_Right) Recorder.nudge(strip.handle, k === Qt.Key_Left ? -step : step)
                    else if (k === Qt.Key_Comma) { strip.handle = "start"; Recorder.nudge("start", e.modifiers & Qt.ShiftModifier ? -1 : 1) }
                    else if (k === Qt.Key_Period) { strip.handle = "end"; Recorder.nudge("end", e.modifiers & Qt.ShiftModifier ? 1 : -1) }
                    else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) strip.handle = strip.handle === "start" ? "end" : "start"
                }
            }
            Keys.onReleased: e => {
                if (e.isAutoRepeat || e.key !== armed) return
                armed = 0
                e.accepted = true
                const k = e.key
                if (root.trimming) {
                    if (k === Qt.Key_Escape) Recorder.trim = ""
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) Recorder.saveTrim()
                    return
                }
                if (!root.shotUp) return
                if (k === Qt.Key_E) Capture.annotate("")
                else if (k === Qt.Key_S) shot.startSaving()
                else if (k === Qt.Key_X) Capture.deleteShot()
                else Capture.cardShown = false
            }

            // ======================================================== Shot card (bottom-left)
            GlassRect {
                id: shot
                variant: "popover"
                radius: Theme.px(22)
                x: Theme.px(40)
                y: parent.height - Theme.px(200)
                width: Theme.px(330)
                height: Theme.px(94)

                // Appears at once where the selection landed (the flying shot becomes its thumbnail); fades out.
                property real p: 0
                Behavior on p { enabled: !root.shotUp; NumberAnimation { duration: Motion.close(Motion.small); easing.type: Motion.easeSmall } }
                Binding on p { value: root.shotUp ? 1 : 0 }
                // Gone at once when the tool opens again, so it isn't in the next frozen frame.
                opacity: Capture.hiding ? 0 : p
                visible: p > 0

                property bool saving: false
                function startSaving() {
                    saving = true
                    Capture.cardHovered = true
                    path.text = Capture.lastShot.replace(Quickshell.env("HOME"), "~")
                    path.forceActiveFocus()
                    path.cursorPosition = path.text.length
                }
                function stopSaving() {
                    saving = false
                    path.focus = false   // else the scope hands focus straight back to the field
                    Capture.cardHovered = hover.hovered
                    keys.forceActiveFocus()
                }

                HoverHandler {
                    id: hover
                    onHoveredChanged: if (!shot.saving) Capture.cardHovered = hovered
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Capture.annotate("")
                }

                Row {
                    x: Theme.px(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(12)

                    ClippingRectangle {
                        width: Theme.px(112)
                        height: Theme.px(70)
                        radius: Theme.px(10)
                        color: Theme.white(0.1)
                        border.width: 1
                        border.color: Theme.white(0.3)
                        Image {
                            anchors.fill: parent
                            source: Capture.lastShot !== "" ? "file://" + Capture.lastShot : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: Theme.px(112) * 2
                            asynchronous: true
                            cache: false
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(330 - 12 - 112 - 12 - 12)
                        spacing: Theme.px(6)
                        Text {
                            text: shot.saving ? "Save as" : Capture.lastCopied ? "Copied to clipboard" : "Saved to Screenshots"
                            font.family: Theme.font
                            font.pixelSize: Theme.px(12.5)
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Flow {
                            visible: !shot.saving
                            width: parent.width
                            spacing: Theme.px(10)
                            Action { label: "Annotate"; key: "E"; onClicked: Capture.annotate("") }
                            Action { label: "Save as"; key: "S"; onClicked: shot.startSaving() }
                            Action { label: "Delete"; key: "X"; onClicked: Capture.deleteShot() }
                        }
                        // Save as: the path, editable; Enter saves, Esc cancels.
                        Rectangle {
                            visible: shot.saving
                            width: parent.width
                            height: Theme.px(26)
                            radius: Theme.px(8)
                            color: Theme.white(0.08)
                            border.width: 1
                            border.color: Theme.alpha(Theme.accent, 0.6)
                            TextInput {
                                id: path
                                anchors.fill: parent
                                anchors.leftMargin: Theme.px(8)
                                anchors.rightMargin: Theme.px(8)
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.px(11)
                                color: Theme.text
                                selectionColor: Theme.alpha(Theme.accent, 0.4)
                                Keys.onPressed: e => {
                                    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                        Capture.saveAs(text, () => shot.stopSaving())
                                        e.accepted = true
                                    } else if (e.key === Qt.Key_Escape) {
                                        shot.stopSaving()
                                        e.accepted = true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ======================================================== Recording card (from the red pill)
            GlassRect {
                id: rec
                variant: "popover"
                radius: Theme.px(18)
                // Where the red pill sat: right of the centred clock.
                readonly property real pillX: parent.width / 2 + Theme.px(80)
                x: Math.min(parent.width - width - Theme.px(12), pillX)
                y: Theme.px(10) + (Theme.px(58) - Theme.px(10)) * Math.min(1, p)
                width: Theme.px(330)
                height: recCol.implicitHeight + Theme.px(24)
                transformOrigin: Item.TopLeft
                scale: 0.85 + 0.15 * p
                opacity: Capture.hiding ? 0 : Math.min(1, p * 2)

                property real p: 0
                Behavior on p {
                    NumberAnimation {
                        duration: root.recUp ? Motion.open(Motion.toastIn) : Motion.close(Motion.toastIn)
                        easing.type: root.recUp ? Motion.easeOpen : Motion.easeClose
                        easing.overshoot: Motion.overshoot
                    }
                }
                Binding on p { value: root.recUp ? 1 : 0 }
                visible: p > 0

                HoverHandler { onHoveredChanged: Recorder.cardHovered = hovered }
                MouseArea { anchors.fill: parent }

                Column {
                    id: recCol
                    x: Theme.px(12)
                    y: Theme.px(12)
                    width: parent.width - Theme.px(24)
                    spacing: Theme.px(10)

                    Row {
                        spacing: Theme.px(12)
                        ClippingRectangle {
                            width: Theme.px(112)
                            height: Theme.px(63)
                            radius: Theme.px(9)
                            color: Theme.white(0.1)
                            Image {
                                anchors.fill: parent
                                source: Recorder.saved ? "file://" + Recorder.saved.thumb : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: Theme.px(24)
                                height: width
                                radius: width / 2
                                color: Qt.rgba(0, 0, 0, 0.5)
                                Icon {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: Theme.px(1)
                                    name: "play"
                                    size: Theme.px(11)
                                    color: Theme.markWhite
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: Theme.px(4)
                                width: dur.implicitWidth + Theme.px(8)
                                height: dur.implicitHeight + Theme.px(2)
                                radius: Theme.px(4)
                                color: Qt.rgba(0, 0, 0, 0.6)
                                Text {
                                    id: dur
                                    anchors.centerIn: parent
                                    text: Recorder.saved ? root.time(Recorder.saved.duration) : ""
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.px(10)
                                    color: Theme.markWhite
                                }
                            }
                        }
                        Column {
                            spacing: Theme.px(3)
                            Text {
                                text: Recorder.trim === "done" ? "Trimmed copy saved" : Recorder.trim === "saving" ? "Saving trimmed copy…" : "Recording saved"
                                font.family: Theme.font
                                font.pixelSize: Theme.px(12.5)
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }
                            Text {
                                text: Recorder.saved ? `~/Videos/Captures · ${root.size(Recorder.saved.size)}` : ""
                                font.family: Theme.font
                                font.pixelSize: Theme.px(11)
                                color: Theme.textMuted
                            }
                        }
                    }
                    Row {
                        spacing: Theme.px(6)
                        Chip { label: "Copy"; onClicked: Recorder.copy() }
                        Chip { label: "Open folder"; onClicked: Recorder.openFolder() }
                        Chip { label: "Trim"; lit: true; onClicked: Recorder.trim === "" ? Recorder.openTrim() : (Recorder.trim = "") }
                    }
                }
            }

            // ======================================================== Trim strip, right under the card
            GlassRect {
                id: strip
                variant: "popover"
                radius: Theme.px(18)
                visible: root.trimming && rec.p > 0
                width: Theme.px(600)
                height: Theme.px(12 + 40 + 8 + 16 + 12)
                x: Math.max(Theme.px(12), Math.min(parent.width - width - Theme.px(12), rec.x + (rec.width - width) / 2))
                y: rec.y + rec.height + Theme.px(10)
                opacity: rec.opacity

                property string handle: "start"
                readonly property real dur: Math.max(0.1, Recorder.saved?.duration ?? 1)
                readonly property real a: Recorder.trimStart / dur
                readonly property real b: Recorder.trimEnd / dur

                MouseArea { anchors.fill: parent }

                // Filmstrip: frames outside the kept part at 50 %.
                ClippingRectangle {
                    id: film
                    x: Theme.px(12)
                    y: Theme.px(12)
                    width: parent.width - Theme.px(24)
                    height: Theme.px(40)
                    radius: Theme.px(8)
                    color: Theme.white(0.06)
                    Row {
                        Repeater {
                            model: Recorder.frames
                            Image {
                                required property string modelData
                                required property int index
                                width: film.width / Math.max(1, Recorder.frames.length)
                                height: film.height
                                source: "file://" + modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                readonly property real mid: (index + 0.5) / Math.max(1, Recorder.frames.length)
                                opacity: mid >= strip.a && mid <= strip.b ? 1 : 0.5
                            }
                        }
                    }
                }
                // The kept part: 3 px accent frame, the active end a little brighter.
                Rectangle {
                    x: film.x + film.width * strip.a - Theme.px(2)
                    y: film.y - Theme.px(2)
                    width: film.width * (strip.b - strip.a) + Theme.px(4)
                    height: film.height + Theme.px(4)
                    radius: Theme.px(9)
                    color: "transparent"
                    border.width: Theme.px(3)
                    border.color: Theme.accent
                    Rectangle {
                        x: strip.handle === "start" ? 0 : parent.width - width
                        width: Theme.px(6)
                        height: parent.height
                        radius: Theme.px(3)
                        color: Theme.accent
                    }
                }
                Item {
                    x: Theme.px(12)
                    y: film.y + film.height + Theme.px(8)
                    width: film.width
                    height: Theme.px(16)
                    Text {
                        text: `${root.time(Recorder.trimStart)} → ${root.time(Recorder.trimEnd)} · ${Math.round(Recorder.trimEnd - Recorder.trimStart)} s`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.px(10.5)
                        color: Theme.textMuted
                    }
                    Text {
                        anchors.right: parent.right
                        text: Recorder.trim === "saving" ? "Saving…" : ", . move start/end · Enter save copy"
                        font.family: Theme.font
                        font.pixelSize: Theme.px(10.5)
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    function time(s: real): string {
        const t = Math.max(0, Math.round(s))
        return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0")
    }
    function size(b: real): string {
        return b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : b >= 1e6 ? Math.round(b / 1e6) + " MB" : Math.max(1, Math.round(b / 1e3)) + " kB"
    }

    // "Annotate [E]": a text action with its key.
    component Action: Item {
        id: act
        property string label
        property string key
        signal clicked()
        implicitWidth: actRow.implicitWidth
        implicitHeight: actRow.implicitHeight
        Row {
            id: actRow
            spacing: Theme.px(5)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: act.label
                font.family: Theme.font
                font.pixelSize: Theme.px(12)
                color: actMouse.containsMouse ? Theme.text : Theme.textMuted
            }
            KeyHint {
                anchors.verticalCenter: parent.verticalCenter
                key: act.key
            }
        }
        MouseArea {
            id: actMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: act.clicked()
        }
    }

    // Copy / Open folder / Trim: 26 px chips, white 12 % (Trim: accent 30 %).
    component Chip: Button {
        id: chip
        property string label
        width: chipText.implicitWidth + Theme.px(22)
        height: Theme.px(26)
        base: Theme.white(0.12)
        litColor: Theme.alpha(Theme.accent, 0.3)
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.family: Theme.font
            font.pixelSize: Theme.px(11.5)
            color: Theme.text
        }
    }
}
