import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services

// Wallpaper on the background layer (the one matugen coloured from).
// Applying a new one (Wallpapers.apply) ripples it in: a circle of the new wallpaper grows from the chosen
// thumbnail until it covers the screen (§5.3, 07-MotionWallpaper: 700 ms InOutCubic); screens without the
// switcher ripple from their bottom centre. Reduced motion: a 150 ms cross-fade.
// Namespace deliberately doesn't start with "glass-shell-": the wallpaper itself isn't blurred.
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "glass-wallpaper"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.glassTint

    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1
    function url(path: string): string { return path ? "file://" + path : "" }

    // What the base layer shows: colors.json's wallpaper, except while a ripple is on its way (matugen
    // rewrites colors.json mid-ripple, and the old wallpaper must stay around the circle until it's done).
    property string shown: ""
    readonly property bool rippling: anim.running || waiting
    property bool waiting: false   // the new wallpaper is still loading
    readonly property string applied: Theme.wallpaper
    onAppliedChanged: if (!rippling) shown = applied
    Component.onCompleted: shown = applied

    Image {
        id: base
        anchors.fill: parent
        source: root.url(root.shown)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(width * root.dpr, height * root.dpr)
    }

    // --- The ripple
    property real progress: 0
    readonly property point origin: Wallpapers.rippleScreen === root.screen?.name
        ? Wallpapers.rippleFrom : Qt.point(width / 2, height)
    // Far enough to reach the farthest corner.
    readonly property real reach: Math.max(Math.hypot(origin.x, origin.y), Math.hypot(width - origin.x, origin.y),
                                           Math.hypot(origin.x, height - origin.y), Math.hypot(width - origin.x, height - origin.y))

    Connections {
        target: Wallpapers
        function onRippleIdChanged() {
            anim.stop()
            root.progress = 0
            root.waiting = true
            incoming.source = root.url(Wallpapers.incoming)
            root.start()
        }
    }
    function start() {
        if (!waiting || incoming.status === Image.Loading) return
        waiting = false
        anim.duration = Motion.fixed(Motion.ripple)
        anim.restart()
    }
    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        from: 0
        to: 1
        easing.type: Motion.reduced ? Easing.Linear : Motion.easeLarge
        onFinished: root.shown = Wallpapers.incoming
    }

    // While the switcher is open, the selected wallpaper is decoded ahead, so Enter's ripple starts at once
    // (incoming then comes from the image cache).
    Image {
        visible: false
        source: Wallpapers.open && Wallpapers.selectedItem ? root.url(Wallpapers.selectedItem.path) : ""
        asynchronous: true
        sourceSize: incoming.sourceSize
    }

    // The new wallpaper, shown through a circle mask. The mask is a screen-sized layer holding the circle
    // (a ClippingRectangle the circle's size would need textures past the GPU limit once it's > 4096 px).
    // Shown until the base layer has the same picture loaded, so the hand-over doesn't flash.
    Image {
        id: incoming
        anchors.fill: parent
        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(width * root.dpr, height * root.dpr)
        onStatusChanged: root.start()
    }
    Item {
        id: mask
        anchors.fill: parent
        // Not visible: false: changes inside a hidden item don't make the window repaint, so the circle
        // would never be drawn while it grows. Opacity 0 keeps it in the scene but draws nothing.
        opacity: 0
        layer.enabled: true
        Rectangle {
            readonly property real r: root.reach * root.progress
            x: root.origin.x - r
            y: root.origin.y - r
            width: 2 * r
            height: 2 * r
            radius: r
            antialiasing: true
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: incoming
        visible: incoming.source != "" && (root.rippling || base.source != incoming.source || base.status !== Image.Ready)
        maskEnabled: !Motion.reduced
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.5
        opacity: Motion.reduced ? root.progress : 1
    }
}
