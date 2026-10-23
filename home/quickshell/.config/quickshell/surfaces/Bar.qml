import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components
import qs.surfaces.bar

// The bar on one screen (DESIGN.md §2, 08-Main / 09-Bar): five separate glass islands that hug their
// content, the temporary pills that bud off the clock and the OSDs that drop out of it. It all lives on one
// transparent full-screen layer so shapes can morph between pills (§7), with the pill popovers and the
// tooltip (§3.1) growing out of them; later phases add the panels here.
// The input mask covers only the pills and whatever is open, so the rest of the screen clicks through to
// the windows. The media, layout and bell popovers take the keyboard while open and close on Esc or a
// click outside (the catcher below); the workspace peek and tooltips are hover-only.
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

    PanelWindow {
        id: win

        screen: root.screen
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "glass-shell-bar"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        readonly property bool modalHere: Shell.popoverModal
            && (Shell.popoverScreen === "" || Shell.popoverScreen === root.screen.name)
        WlrLayershell.keyboardFocus: modalHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region {
            Region { item: win.modalHere ? catcher : null }
            Region { item: peek.visible ? peek.body : null }
            Region { item: mediaPopover.visible ? mediaPopover.body : null }
            Region { item: layoutMenu.visible ? layoutMenu.body : null }
            Region { item: bellMenu.visible ? bellMenu.body : null }
            Region { item: workspaces }
            Region { item: media.visible ? media : null }
            Region { item: clock }
            Region { item: recording.visible ? recording.pill : null }
            Region { item: keyMode.visible ? keyMode.pill : null }
            Region { item: status }
            Region { item: bell }
        }

        readonly property real inset: Theme.px(12)
        readonly property real top: Theme.px(10)
        readonly property real gap: Theme.px(8)

        // Click outside: while a menu popover is open the input mask covers the whole screen and a press
        // anywhere but a pill or the popover lands here and closes it (that click doesn't reach the window
        // below). Hyprland's focus grab doesn't fire while this layer holds the keyboard exclusively.
        MouseArea {
            id: catcher
            anchors.fill: parent
            enabled: win.modalHere
            acceptedButtons: Qt.AllButtons
            onPressed: Shell.closePopover()
        }

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

        // --- Centre: the clock, with the OSD and the temporary pills underneath it.
        OsdDrop { clock: clock }

        // Recording (placeholder until Phase 8): red dot with a halo + timer; click or Super+Shift+R stops.
        SplitPill {
            id: recording
            clock: clock
            side: "right"
            tone: "error"
            shown: Modes.recording
            padLeft: Theme.px(13)
            spacing: Theme.px(10)
            onClicked: Modes.toggleRecording()

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
                text: Modes.recordingTime
                color: Theme.textOnError
                font.family: Theme.fontMono
                font.weight: Font.Medium
            }
            KeyHint {
                anchors.verticalCenter: parent.verticalCenter
                key: "Super Shift R"
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

        // --- Right: status and bell; the row is right-aligned so the status pill stretches leftwards.
        Row {
            anchors { right: parent.right; rightMargin: win.inset; top: parent.top; topMargin: win.top }
            spacing: win.gap
            StatusPill { id: status }
            BellPill { id: bell }
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
        BarTooltip {}
    }
}
