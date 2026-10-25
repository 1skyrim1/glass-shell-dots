import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components
import qs.surfaces.bar
import qs.surfaces.launcher
import qs.surfaces.control
import qs.surfaces.notifications
import qs.surfaces.wallpaper

// The bar on one screen (DESIGN.md §2, 08-Main / 09-Bar): five separate glass islands that hug their
// content, the temporary pills that bud off the clock and the OSDs that drop out of it. It all lives on one
// transparent full-screen layer so shapes can morph between pills (§7), with the pill popovers and the
// tooltip (§3.1) growing out of them, and the panels growing out of theirs (launcher: §3.3, Control
// Center: §3.4, notification center: §3.5; the wallpaper switcher, §3.6, rises from the bottom edge).
// Toasts drip out of the bell, under popovers and panels (§4).
// The input mask covers only the pills and whatever is open, so the rest of the screen clicks through to
// the windows. Panels and the media, layout and bell popovers take the keyboard while open and close on
// Esc or a click outside (the catcher below); the workspace peek and tooltips are hover-only.
Scope {
    id: root

    required property ShellScreen screen

    // Keeps tiled windows below the pills: 10 px inset + 38 px pill (§1.4 "Reserved top area").
    // Draws nothing and takes no input; not "glass-shell-…", so it isn't blurred.
    PanelWindow {
        screen: root.screen
        WlrLayershell.namespace: "glass-reserve"
        anchors { top: true; left: true; right: true }
        implicitHeight: Math.round(48 * Theme.scale)
        exclusiveZone: implicitHeight
        color: "transparent"
        mask: Region {}
    }

    // The launcher dims the desktop 34 % (§3.3), the notification center 22 % (Notifications.dc.html) and
    // the Control Center reuses the launcher's dim. It's a full-screen layer, so it
    // also covers the bar's strip between the pills. Not blurred: a layer of its own whose namespace isn't
    // "glass-shell-…" (the bar's layer blurs everything above its alpha threshold). Created before the bar's
    // layer and always mapped, so it stays under the pills and the panels.
    // Fullscreen windows are drawn above the Top layer, so while one is up the dim and the bar move to Overlay:
    // panels, the overview's neighbours, OSDs and critical toasts still show over a fullscreen game (§4).
    readonly property bool fullscreen: Shell.fullscreenOn(screen.name)
    readonly property int layer: fullscreen ? WlrLayer.Overlay : WlrLayer.Top

    PanelWindow {
        screen: root.screen
        WlrLayershell.layer: root.layer
        WlrLayershell.namespace: "glass-dim"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        mask: Region {}
        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.scrim, 0.34)
            opacity: Math.max(launcher.dimLevel, control.dimLevel, notifCenter.dimLevel * 0.22 / 0.34)
            visible: opacity > 0
        }
        // 10 s before the idle lock the screen dims to 45 % (30-SessionStates "About to lock").
        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.scrim, 0.55)
            opacity: Idle.warning ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
        }
    }

    // Keep awake (Control Center, Modes): holds the idle chain back (services/Idle.qml respects inhibitors).
    IdleInhibitor {
        window: win
        enabled: Modes.keepAwake
    }

    PanelWindow {
        id: win

        screen: root.screen
        WlrLayershell.layer: root.layer
        WlrLayershell.namespace: "glass-shell-bar"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        readonly property bool modalHere: launcher.shown || control.shown || notifCenter.shown || wallpaper.shown || Shell.popoverModal
            && (Shell.popoverScreen === "" || Shell.popoverScreen === root.screen.name)
        WlrLayershell.keyboardFocus: modalHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region {
            Region { item: win.modalHere ? catcher : null }
            Region { item: launcher.active ? launcher.body : null }
            Region { item: control.active ? control.body : null }
            Region { item: notifCenter.active ? notifCenter.body : null }
            Region { item: wallpaper.active ? wallpaper.body : null }
            Region { item: toasts }
            Region { item: peek.visible ? peek.body : null }
            Region { item: mediaPopover.visible ? mediaPopover.body : null }
            Region { item: layoutMenu.visible ? layoutMenu.body : null }
            Region { item: bellMenu.visible ? bellMenu.body : null }
            Region { item: win.pillsIn ? workspaces : null }
            Region { item: win.pillsIn && media.visible ? media : null }
            Region { item: win.pillsIn ? clock : null }
            Region { item: recording.visible ? recording.pill : null }
            Region { item: keyMode.visible ? keyMode.pill : null }
            Region { item: sharing.visible ? sharing.pill : null }
            Region { item: win.pillsIn ? status : null }
            Region { item: win.pillsIn ? bell : null }
        }

        // Lock / unlock / log in (06-MotionSession): the pills float up and fade, and drop back in from the top:
        // the clock first, then the left pills, then the right ones (Session.barT 0 = gone, 1 = in place).
        function bar(a: real, b: real): real {
            const u = Math.max(0, Math.min(1, (Session.barT - a) / (b - a)))
            return u * u * (3 - 2 * u)
        }
        readonly property real clockIn: bar(0, 0.35)
        readonly property real leftIn: bar(0, 0.8)
        readonly property real rightIn: bar(0.15, 1)

        // Fullscreen (§5.3, 05-MotionWindows "Fullscreen"): every pill floats up and fades while the window
        // grows to the edges (260 ms), and comes back when another window or workspace takes focus.
        property real fsIn: root.fullscreen ? 0 : 1
        Behavior on fsIn { NumberAnimation { duration: Motion.fixed(Motion.fullscreen); easing.type: Motion.easeLarge } }
        readonly property bool pillsIn: fsIn > 0.5

        readonly property real inset: Theme.px(12)
        readonly property real top: Theme.px(10)
        readonly property real gap: Theme.px(8)

        // Click outside: while a panel or menu popover is open the input mask covers the whole screen and a
        // press anywhere but a pill, panel or popover lands here and closes it (that click doesn't reach the
        // window below). Hyprland's focus grab doesn't fire while this layer holds the keyboard exclusively.
        MouseArea {
            id: catcher
            anchors.fill: parent
            enabled: win.modalHere
            acceptedButtons: Qt.AllButtons
            onPressed: Shell.closeTop()
        }

        PillGroup {
            shown: win.leftIn * win.fsIn
            // --- Left: workspaces, and the media pill sliding out from behind them.
            MediaPill {
                id: media
                anchor: workspaces
                gap: win.gap
                y: win.top
            }
            WorkspacePill {
                id: workspaces
                x: win.inset
                y: win.top
            }
        }

        // The OSD drops out of the clock even while the pills are away for a fullscreen window (volume keys in a
        // game still show it), so it isn't part of the clock's group. Under the clock pill.
        PillGroup {
            shown: win.clockIn
            OsdDrop { clock: clock }
        }

        PillGroup {
            shown: win.clockIn * win.fsIn
            // --- Centre: the clock, with the temporary pills underneath it.

            // Recording (22-CaptureWindow): red dot with a halo, "REC" + timer and a Stop chip; click or
            // Super+Shift+R stops. When it merges back, the "Recording saved" card drops out of it.
            SplitPill {
                id: recording
                clock: clock
                side: "right"
                tone: "error"
                shown: Recorder.recording
                padLeft: Theme.px(13)
                padRight: Theme.px(8)
                spacing: Theme.px(10)
                onClicked: Recorder.stop()

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(10)
                    height: width
                    // 4 px halo around the dot; like the design's box-shadow it takes no space.
                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.px(18)
                        height: width
                        radius: width / 2
                        color: Theme.alpha(Theme.error, 0.25)
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.error
                    }
                }
                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "REC " + Recorder.recordingTime
                    color: Theme.textOnError
                    font.family: Theme.fontMono
                    font.weight: Font.Medium
                }
                // Stop chip: 28 px, error 22 %.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: stopRow.implicitWidth + Theme.px(20)
                    height: Theme.px(28)
                    radius: height / 2
                    color: Theme.alpha(Theme.error, 0.22)
                    Row {
                        id: stopRow
                        anchors.centerIn: parent
                        spacing: Theme.px(6)
                        BarText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Stop"
                            color: Theme.textOnError
                            font.pixelSize: Theme.px(12)
                        }
                        KeyHint {
                            anchors.verticalCenter: parent.verticalCenter
                            key: "Super Shift R"
                        }
                    }
                }
            }

            // Sharing (25-SharePicker "While sharing"): green, "Sharing <what>" + Stop. Same motion as recording;
            // buds off the red pill when both are up.
            SplitPill {
                id: sharing
                clock: recording.visible ? recording.pill : clock
                side: "right"
                tone: "success"
                shown: Share.sharing
                padLeft: Theme.px(12)
                padRight: Theme.px(6)
                spacing: Theme.px(9)
                onClicked: Share.stop()

                // Keep the last label while the pill merges back.
                property string label: ""
                Connections {
                    target: Share
                    function onLabelChanged() { if (Share.label !== "") sharing.label = Share.label }
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "monitor"
                    size: Theme.px(15)
                    color: Theme.textOnSuccess
                }
                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Sharing " + sharing.label
                    color: Theme.textOnSuccess
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: shareStop.implicitWidth + Theme.px(20)
                    height: Theme.px(26)
                    radius: height / 2
                    color: Theme.white(0.14)
                    BarText {
                        id: shareStop
                        anchors.centerIn: parent
                        text: "Stop"
                        color: Theme.textOnSuccess
                        font.pixelSize: Theme.px(12)
                    }
                }
            }

            // Key mode: while a Hyprland submap is active, its name and keys (they're why typing doesn't work).
            SplitPill {
                id: keyMode
                clock: clock
                side: "left"
                tone: "accent"
                shown: Modes.submap !== ""
                padRight: Theme.px(10)
                spacing: Theme.px(8)

                // Keep the last submap's content while the pill merges back.
                property string name: ""
                Connections {
                    target: Modes
                    function onSubmapChanged() { if (Modes.submap !== "") keyMode.name = Modes.submap }
                }

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: keyMode.name.toUpperCase()
                    color: Theme.textOnContainer
                    font.pixelSize: Theme.px(12)
                    font.weight: Font.DemiBold
                    font.letterSpacing: Theme.px(0.8)
                }
                Repeater {
                    model: Modes.submapKeys[keyMode.name] ?? []
                    KeyHint {
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        key: modelData
                        alwaysVisible: true
                    }
                }
            }

            ClockPill {
                id: clock
                x: Math.round((win.width - width) / 2)
                y: win.top
            }
        }

        PillGroup {
            shown: win.rightIn * win.fsIn
            // --- Right: status and bell; the row is right-aligned so the status pill stretches leftwards.
            Row {
                anchors { right: parent.right; rightMargin: win.inset; top: parent.top; topMargin: win.top }
                spacing: win.gap
                StatusPill { id: status }
                BellPill { id: bell }
            }
        }

        // --- Toasts: above the pills (they drip out of the bell), under popovers and panels.
        ToastStack {
            id: toasts
            bell: bell
        }

        // --- Popovers, above the pills so the droplet grows over its pill.
        WorkspacePeek {
            id: peek
            pill: workspaces
            target: workspaces.dotItem(Shell.peekId)
            screenName: root.screen.name
        }
        // A hover-opened peek closes shortly after the mouse leaves both the dots and the peek.
        Timer {
            running: Shell.popover === "peek" && workspaces.peekByHover && !workspaces.dotHovered && !peek.hovered
            interval: Motion.peekGrace
            onTriggered: Shell.closePopoverIf("peek")
        }
        MediaPopover {
            id: mediaPopover
            pill: media
            screenName: root.screen.name
        }
        LayoutMenu {
            id: layoutMenu
            pill: status
            target: status.badge
            screenName: root.screen.name
        }
        BellMenu {
            id: bellMenu
            pill: bell
            screenName: root.screen.name
        }

        // --- Panels, above the pills they grow out of.
        Launcher {
            id: launcher
            clock: clock
            screenName: root.screen.name
        }
        ControlCenter {
            id: control
            pill: status
            screenName: root.screen.name
        }
        NotificationCenter {
            id: notifCenter
            clock: clock
            screenName: root.screen.name
        }
        // Rises from the bottom edge rather than out of a pill; no dim (20-Wallpaper).
        WallpaperSheet {
            id: wallpaper
            screenName: root.screen.name
        }
        BarTooltip {}
    }

    // A full-screen group of pills that floats up and fades together (coordinates stay the window's).
    component PillGroup: Item {
        id: group
        property real shown: 1
        anchors.fill: parent
        opacity: shown
        visible: shown > 0
        transform: Translate { y: -Theme.px(16) * (1 - group.shown) }
    }
}
