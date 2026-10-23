import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Wallpaper on the background layer (the one matugen coloured from). Phase 7 adds the ripple.
// Namespace deliberately doesn't start with "glass-shell-": the wallpaper itself isn't blurred.
PanelWindow {
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "glass-wallpaper"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.glassTint

    Image {
        anchors.fill: parent
        source: Theme.wallpaper ? "file://" + Theme.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(width * (QsWindow.window?.devicePixelRatio ?? 1), height * (QsWindow.window?.devicePixelRatio ?? 1))
    }
}
