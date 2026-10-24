import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// Power menu (DESIGN.md §3.8, 32-Power; values from Power.dc.html): Super+Esc or the Control Center's power
// button. Dim + blur, five 150 × 150 tiles (radius 34): Lock L, Suspend S, Log out O, Reboot R, Power off P.
// Nothing else on screen; the letters only show with key hints. Reboot and Power off arm on the first press:
// the tile turns red, a ring drains for 3 s and "P again" asks for the same key or a click (30 "Power menu:
// confirm"); anything else disarms. ←/→ (H/L) move, Enter presses, Esc / a click outside closes.
// Motion (§5.3): dim + blur (200 ms), then the tiles rise 40 ms apart with a small bounce (300 ms).
// The dim sits in a "glass-shell-" layer above the blur threshold, so Hyprland blurs the whole desktop behind.
Scope {
    id: root

    required property ShellScreen screen

    readonly property bool shown: Shell.isOpen("power") && (Shell.panelScreen === "" || Shell.panelScreen === screen.name)

    readonly property var items: [
        { kind: "lock", label: "Lock", icon: "lock", key: "L" },
        { kind: "suspend", label: "Suspend", icon: "moon", key: "S" },
        { kind: "logout", label: "Log out", icon: "log-out", key: "O" },
        { kind: "reboot", label: "Reboot", icon: "refresh", key: "R" },
        { kind: "poweroff", label: "Power off", icon: "power", key: "P" }
    ]
    property int current: 1
    property string armed: ""
    property real armLeft: 1

    function press(i: int) {
        const kind = items[i].kind
        current = i
        if ((kind === "reboot" || kind === "poweroff") && armed !== kind) {
            armed = kind
            drain.restart()
            return
        }
        armed = ""
        Shell.close("power")
        if (kind === "lock") Session.lock(false)
        else if (kind === "suspend") Session.suspend()
        else Session.end(kind)
    }

    NumberAnimation {
        id: drain
        target: root
        property: "armLeft"
        from: 1
        to: 0
        duration: Motion.arm
        onFinished: root.armed = ""
    }

    property real dim: 0
    property real rise: 0
    NumberAnimation { id: dimAnim; target: root; property: "dim" }
    NumberAnimation { id: riseAnim; target: root; property: "rise" }
    Connections {
        target: root
        function onShownChanged() {
            dimAnim.stop()
            riseAnim.stop()
            root.armed = ""
            if (root.shown) {
                root.current = 1
                dimAnim.to = 1
                dimAnim.duration = Motion.fixed(Motion.powerDim)
                dimAnim.easing.type = Motion.easeSmall
                // Tiles start once the dim is most of the way there; the last one lands 4 × 40 ms later.
                riseAnim.to = 1
                riseAnim.duration = Motion.fixed(Motion.powerTiles + 4 * Motion.tileStagger + Motion.powerDim * 0.6)
                riseAnim.easing.type = Easing.Linear
            } else {
                dimAnim.to = 0
                dimAnim.duration = Motion.close(Motion.powerDim + Motion.powerTiles)
                dimAnim.easing.type = Motion.easeClose
                riseAnim.to = 0
                riseAnim.duration = Motion.close(Motion.powerTiles)
                riseAnim.easing.type = Motion.easeClose
            }
            dimAnim.start()
            riseAnim.start()
        }
    }

    // Created while needed: Shapes (the icons) in a window that was created hidden don't draw the first time.
    LazyLoader {
        active: root.shown || root.dim > 0
        PanelWindow {
            id: win

            screen: root.screen
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "glass-shell-power"
            WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            FocusScope {
                id: keys
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()

                Rectangle {
                    anchors.fill: parent
                    color: Theme.alpha(Theme.scrim, 0.5)
                    opacity: root.dim
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.shown
                    onPressed: Shell.close("power")
                }

                Row {
                    id: tiles
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Theme.px(375)
                    spacing: Theme.px(18)

                    Repeater {
                        model: root.items
                        Item {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool isArmed: root.armed === modelData.kind
                            readonly property bool isCurrent: root.current === index
                            width: Theme.px(150)
                            height: width

                            // This tile's rise: starts after the dim, 40 ms after the previous tile; OutBack bounce.
                            readonly property real total: Motion.powerTiles + 4 * Motion.tileStagger + Motion.powerDim * 0.6
                            readonly property real t: Math.max(0, Math.min(1, (root.rise * total - Motion.powerDim * 0.6 - index * Motion.tileStagger) / Motion.powerTiles))
                            readonly property real e: Motion.reduced ? t : 1 + 2.4 * Math.pow(t - 1, 3) + 1.4 * Math.pow(t - 1, 2)
                            opacity: Math.min(1, t * 2)
                            transform: Translate { y: Theme.px(40) * (1 - tile.e) }

                            // Selected: 3 px accent 55 % ring (Power.dc.html); armed: red with a 3 px error 20 % halo.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -Theme.px(3)
                                radius: Theme.px(34) + Theme.px(3)
                                color: "transparent"
                                border.width: Theme.px(3)
                                border.color: tile.isArmed ? Theme.alpha(Theme.error, 0.2) : Theme.alpha(Theme.accent, 0.55)
                                visible: tile.isCurrent || tile.isArmed
                            }
                            GlassRect {
                                id: glass
                                anchors.fill: parent
                                radius: Theme.px(34)
                                tone: tile.isArmed ? "wrong" : ""
                                hovered: mouse.containsMouse
                                pressed: mouse.pressed
                            }
                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.current = tile.index
                                onClicked: root.press(tile.index)
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.px(12)
                                scale: glass.scale
                                Item {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Theme.px(30)
                                    height: width
                                    Icon {
                                        id: tileIcon
                                        anchors.centerIn: parent
                                        visible: !tile.isArmed
                                        name: tile.modelData.icon
                                        size: Theme.px(30)
                                        strokeWidth: 1.8
                                    }
                                    Ring {
                                        anchors.centerIn: parent
                                        width: Theme.px(36)
                                        visible: tile.isArmed
                                        progress: root.armLeft
                                        stroke: 2.5
                                        color: Theme.textOnError
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tile.isArmed ? tile.modelData.key + " again" : tile.modelData.label
                                    color: tile.isArmed ? Theme.textOnError : Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.px(14)
                                    font.weight: Font.Medium
                                }
                            }
                            KeyHint {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: Theme.px(12)
                                anchors.rightMargin: Theme.px(14)
                                key: tile.modelData.key
                            }
                        }
                    }
                }

                Keys.onPressed: event => {
                    const k = event.key
                    const hit = root.items.findIndex(i => i.key.charCodeAt(0) === k)
                    if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) return
                    if (hit >= 0) root.press(hit)
                    else if (k === Qt.Key_Left || k === Qt.Key_H) { root.armed = ""; root.current = Math.max(0, root.current - 1) }
                    else if (k === Qt.Key_Right) { root.armed = ""; root.current = Math.min(root.items.length - 1, root.current + 1) }
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.press(root.current)
                    else if (k === Qt.Key_Escape) { root.armed !== "" ? (root.armed = "") : Shell.close("power") }
                    else if (k === Qt.Key_Tab) { root.armed = ""; root.current = (root.current + 1) % root.items.length }
                    else if (k === Qt.Key_Alt) { KeyHints.held = true; return }
                    else root.armed = ""
                    event.accepted = true
                }
                Keys.onReleased: event => { if (event.key === Qt.Key_Alt) KeyHints.held = false }
            }
        }
    }
}
