import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.surfaces.session

// The session lock (DESIGN.md §3.8 "Lock", top of the layer stack in §4), driven by services/Session.qml.
// WlSessionLock maps a lock surface on every screen; Hyprland shows nothing else until it's released.
// `qs ipc call lock preview` shows the same screen on an ordinary Overlay layer with fake auth instead.
Scope {
    WlSessionLock {
        locked: Session.surfaceUp && !Session.preview

        WlSessionLockSurface {
            id: surface
            color: "black"
            LockScreen {
                anchors.fill: parent
                screenName: surface.screen?.name ?? ""
            }
        }
    }

    LazyLoader {
        active: Session.preview
        Variants {
            model: Quickshell.screens
            PanelWindow {
                required property var modelData
                screen: modelData
                visible: Session.surfaceUp
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "glass-lock-preview"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                exclusionMode: ExclusionMode.Ignore
                anchors { top: true; bottom: true; left: true; right: true }
                color: "black"
                LockScreen {
                    anchors.fill: parent
                    screenName: modelData.name
                }
            }
        }
    }
}
