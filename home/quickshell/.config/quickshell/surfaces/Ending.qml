import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.surfaces.session

// The shutting-down screen of the session (EndingView) on a layer above everything but the lock: Overlay,
// not "glass-shell-…" (black, nothing to blur). Holds the keyboard so Esc can cancel.
PanelWindow {
    id: root

    visible: Session.endT > 0
    onVisibleChanged: if (visible) view.forceActiveFocus()
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "glass-ending"
    WlrLayershell.keyboardFocus: Session.ending !== "" && !Session.surfaceUp ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    EndingView {
        id: view
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Session.cancelEnd()
        Keys.onReturnPressed: Session.forceEnd()
        Keys.onEnterPressed: Session.forceEnd()
    }
}
