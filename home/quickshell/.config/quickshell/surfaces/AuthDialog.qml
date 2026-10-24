import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components

// Password prompt (DESIGN.md §3.8 "Polkit", 31-Polkit; values from Polkit.dc.html), for services/Polkit.qml.
// Dim + blur, a 460 px dialog (radius 30) scales in from 92 %: shield tile with the requesting app's icon,
// "Authentication required" + the action's sentence, the user, the password field with the accent ring,
// collapsible Details (Tab: program, action id, time · PID) and Cancel Esc / Authenticate Enter.
// A wrong password shakes the dialog and turns the field red with the tries left (30 "Polkit: wrong
// password"); after the 3rd Polkit gives up and sends a notification. Only one at a time, always centred on
// the focused screen, above the capture tool and the power menu (§4 layers).
// The fields are generic (icon, title, message, details), so other prompts (pinentry) can use it later.
Scope {
    id: root

    required property ShellScreen screen

    readonly property bool shown: Polkit.active && !Session.locked
        && screen === (Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0])
    readonly property var flow: Polkit.flow

    property bool details: true
    // Keep the last request's text while the dialog animates out.
    property string message: ""
    property string appIcon: ""
    onFlowChanged: if (flow) { message = flow.message; appIcon = flow.iconName; typed = "" }
    property string typed: ""   // the field's text (the TextInput lives in the lazily created window)
    onTypedChanged: if (typed !== "" && Polkit.status === "wrong") Polkit.status = ""

    // The dim first (200 ms), then the dialog scales in from 92 % (260 ms).
    property real p: 0
    NumberAnimation on p { id: anim; running: false }
    onShownChanged: {
        anim.stop()
        anim.to = shown ? 1 : 0
        anim.duration = shown ? Motion.open(Motion.powerDim + Motion.dialogIn) : Motion.close(Motion.dialogIn)
        anim.easing.type = shown ? Easing.Linear : Motion.easeClose
        anim.start()
    }
    readonly property real dimP: Math.min(1, p * (Motion.powerDim + Motion.dialogIn) / Motion.powerDim)
    readonly property real dlgP: Math.max(0, (p * (Motion.powerDim + Motion.dialogIn) - Motion.powerDim) / Motion.dialogIn)

    // --- Shake on a wrong password (and the field empties)
    property real shakeT: 1
    Connections {
        target: Polkit
        function onFailuresChanged() {
            if (Polkit.failures === 0) return
            root.typed = ""
            if (Motion.shake) shake.restart()
        }
    }
    NumberAnimation { id: shake; target: root; property: "shakeT"; from: 0; to: 1; duration: Motion.shakeTime }

    // Created while needed: Shapes (the icons) in a window that was created hidden don't draw the first time.
    LazyLoader {
        active: root.shown || root.p > 0
        PanelWindow {
            id: win

            screen: root.screen
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "glass-shell-prompt"
            WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.scrim, 0.55)
                opacity: root.dimP
            }

            Item {
                id: dialog
                width: Theme.px(460)
                height: column.implicitHeight + 2 * Theme.px(26)
                x: (win.width - width) / 2 + Motion.frames(root.shakeT, Motion.shakeKeys) * Theme.px(1)
                y: (win.height - height) / 2
                opacity: Math.min(1, root.dlgP * 1.5)
                scale: Motion.reduced ? 1 : 0.92 + 0.08 * (1 - Math.pow(1 - root.dlgP, 3))

                GlassRect {
                    anchors.fill: parent
                    variant: "dialog"
                }

                Column {
                    id: column
                    x: Theme.px(26)
                    y: Theme.px(26)
                    width: parent.width - 2 * x

                    // Shield tile + the app's icon, title + sentence
                    Row {
                        spacing: Theme.px(16)
                        Item {
                            width: Theme.px(58)
                            height: width
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.px(18)
                                color: Theme.accentContainer
                                Icon {
                                    anchors.centerIn: parent
                                    name: "shield-check"
                                    size: Theme.px(28)
                                    strokeWidth: 1.9
                                    color: Theme.textOnContainer
                                }
                            }
                            Rectangle {
                                x: parent.width - width + Theme.px(6)
                                y: parent.height - height + Theme.px(6)
                                width: Theme.px(26)
                                height: width
                                radius: Theme.px(9)
                                color: Theme.alpha(Theme.successContainer, 1)
                                border.width: Theme.px(2)
                                border.color: Theme.glassTint
                                IconImage {
                                    id: appIcon
                                    anchors.centerIn: parent
                                    implicitSize: Theme.px(15)
                                    source: root.appIcon !== "" ? Quickshell.iconPath(root.appIcon, true) : ""
                                    visible: status === Image.Ready
                                }
                                Icon {
                                    anchors.centerIn: parent
                                    visible: !appIcon.visible
                                    name: "shield"
                                    size: Theme.px(13)
                                    strokeWidth: 2.4
                                    color: Theme.textOnSuccess
                                }
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: column.width - Theme.px(58 + 16)
                            spacing: Theme.px(3)
                            Text {
                                text: "Authentication required"
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.px(18)
                                font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                text: root.message
                                wrapMode: Text.Wrap
                                color: Theme.textMuted
                                font.family: Theme.font
                                font.pixelSize: Theme.px(13)
                            }
                        }
                    }

                    Item { width: 1; height: Theme.px(22) }

                    // The user asked for (polkit picks an administrator)
                    Row {
                        spacing: Theme.px(10)
                        Rectangle {
                            width: Theme.px(28)
                            height: width
                            radius: width / 2
                            color: Theme.alpha(Theme.accent, 0.25)
                            Icon {
                                anchors.centerIn: parent
                                name: "user"
                                size: Theme.px(15)
                                color: Theme.textOnContainer
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.flow?.selectedIdentity?.displayName ?? Session.user
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.Medium
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Polkit.wheel
                            text: "· wheel"
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.px(13)
                        }
                    }

                    Item { width: 1; height: Theme.px(12) }

                    // Password field: white 8 %, 1.5 px accent ring + 4 px accent 18 % halo; red when wrong.
                    Item {
                        id: field
                        readonly property bool red: Polkit.status === "wrong"
                        width: parent.width
                        height: Theme.px(50)
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -Theme.px(4)
                            radius: Theme.px(20)
                            color: "transparent"
                            border.width: Theme.px(4)
                            border.color: field.red ? Theme.alpha(Theme.error, 0.2) : Theme.alpha(Theme.accent, 0.18)
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.px(16)
                            color: field.red ? Theme.alpha(Theme.errorContainer, 0.4) : Theme.white(0.08)
                            border.width: Theme.px(1.5)
                            border.color: field.red ? Theme.alpha(Theme.error, 0.8) : Theme.accent
                        }
                        Row {
                            x: Theme.px(16)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(7)
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "lock"
                                size: Theme.px(16)
                                color: field.red ? Theme.error : Theme.accent
                            }
                            Item { width: Theme.px(6); height: 1 }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: field.red && root.typed === ""
                                text: "Wrong password"
                                color: Theme.textOnError
                                font.family: Theme.font
                                font.pixelSize: Theme.px(13)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: (root.flow?.responseVisible ?? false) && root.typed !== ""
                                text: root.typed
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.px(14)
                            }
                            Repeater {
                                model: root.flow?.responseVisible ? 0 : Math.min(root.typed.length, 32)
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.px(9)
                                    height: width
                                    radius: width / 2
                                    color: Theme.text
                                    opacity: Polkit.status === "checking" ? 0.5 : 1
                                }
                            }
                            Rectangle {
                                id: caret
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(2)
                                height: Theme.px(20)
                                color: Theme.accent
                                visible: input.activeFocus && Polkit.status !== "checking"
                                SequentialAnimation on opacity {
                                    running: caret.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1; duration: 0 }
                                    PauseAnimation { duration: Motion.caretBlink }
                                    NumberAnimation { to: 0; duration: 0 }
                                    PauseAnimation { duration: Motion.caretBlink }
                                }
                            }
                        }
                        Ring {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.px(16)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(18)
                            visible: Polkit.status === "checking"
                            spinning: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: input.forceActiveFocus()
                        }
                    }

                    // "2 tries left" / PAM's own error (an account locked by faillock)
                    Text {
                        readonly property string supp: root.flow?.supplementaryIsError ? root.flow.supplementaryMessage : ""
                        readonly property int remaining: Polkit.maxTries - Polkit.failures
                        visible: text !== ""
                        topPadding: Theme.px(6)
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: supp !== "" ? supp : Polkit.failures > 0 ? `${remaining} ${remaining === 1 ? "try" : "tries"} left` : ""
                        color: Theme.alpha(Theme.textOnError, 0.85)
                        font.family: Theme.font
                        font.pixelSize: Theme.px(12)
                    }

                    Item { width: 1; height: Theme.px(14) }

                    // Details (Tab)
                    Rectangle {
                        width: parent.width
                        height: detailCol.implicitHeight + Theme.px(24)
                        radius: Theme.px(16)
                        color: Theme.alpha(Theme.scrim, 0.35)
                        clip: true
                        Behavior on height { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.details = !root.details
                        }
                        Column {
                            id: detailCol
                            x: Theme.px(14)
                            y: Theme.px(12)
                            width: parent.width - 2 * x
                            Item {
                                width: parent.width
                                height: Theme.px(20)
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.px(8)
                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: root.details ? "chevron-down" : "chevron-right"
                                        size: Theme.px(13)
                                        strokeWidth: 2.4
                                    }
                                    Text {
                                        text: "Details"
                                        color: Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: Theme.px(12.5)
                                        font.weight: Font.Medium
                                    }
                                }
                                KeyHint {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    key: "Tab"
                                }
                            }
                            Item { width: 1; height: root.details ? Theme.px(6) : 0 }
                            Repeater {
                                model: root.details ? [
                                    Polkit.program !== "" ? ["Program", Polkit.program, true] : null,
                                    ["Action", root.flow?.actionId ?? "", true],
                                    ["Requested", Qt.formatDateTime(new Date(Polkit.requestedAt), "HH:mm")
                                                  + (Polkit.pid > 0 ? " · PID " + Polkit.pid : ""), false]
                                ].filter(r => r !== null) : []
                                Row {
                                    required property var modelData
                                    spacing: Theme.px(10)
                                    Text {
                                        width: Theme.px(72)
                                        text: parent.modelData[0]
                                        color: Theme.textFaint
                                        font.family: Theme.font
                                        font.pixelSize: Theme.px(12)
                                        lineHeight: Theme.px(20)
                                        lineHeightMode: Text.FixedHeight
                                    }
                                    Text {
                                        width: detailCol.width - Theme.px(82)
                                        text: parent.modelData[1]
                                        elide: Text.ElideMiddle
                                        color: Theme.text
                                        font.family: parent.modelData[2] ? Theme.fontMono : Theme.font
                                        font.pixelSize: Theme.px(12)
                                        lineHeight: Theme.px(20)
                                        lineHeightMode: Text.FixedHeight
                                    }
                                }
                            }
                        }
                    }

                    Item { width: 1; height: Theme.px(20) }

                    Row {
                        spacing: Theme.px(10)
                        Button {
                            width: (column.width - Theme.px(10)) / 2
                            height: Theme.px(46)
                            base: Theme.white(0.10)
                            onClicked: Polkit.cancel()
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(8)
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Cancel"
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.px(14)
                                }
                                KeyHint { anchors.verticalCenter: parent.verticalCenter; key: "Esc" }
                            }
                        }
                        Button {
                            width: (column.width - Theme.px(10)) / 2
                            height: Theme.px(46)
                            base: Theme.accent
                            enabled: Polkit.status !== "checking"
                            onClicked: root.submit()
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(8)
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Authenticate"
                                    color: Theme.textOnAccent
                                    font.family: Theme.font
                                    font.pixelSize: Theme.px(14)
                                    font.weight: Font.DemiBold
                                }
                                KeyHint { anchors.verticalCenter: parent.verticalCenter; key: "Enter"; ink: Theme.textOnAccent }
                            }
                        }
                    }
                }
            }

            TextInput {
                id: input
                width: 1
                height: 1
                opacity: 0
                text: root.typed
                onTextChanged: root.typed = text
                Component.onCompleted: forceActiveFocus()
                echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                readOnly: Polkit.status === "checking"
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Alt) { KeyHints.held = true; return }
                    if (event.key === Qt.Key_Escape) Polkit.cancel()
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.submit()
                    else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) root.details = !root.details
                    else return
                    event.accepted = true
                }
                Keys.onReleased: event => { if (event.key === Qt.Key_Alt) KeyHints.held = false }
            }
        }
    }

    function submit() {
        if (!flow || !flow.isResponseRequired || Polkit.status === "checking") return
        Polkit.submit(typed)
    }
}
