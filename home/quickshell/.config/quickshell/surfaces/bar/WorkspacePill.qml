import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.components

// Workspace pill (DESIGN.md §2.1, 09-Bar "Workspace pill up close"): five dots, then the focused window's
// icon + title. Dots: active = accent capsule 18 × 8, has windows = filled, empty = ring, urgent = tertiary
// with a halo. The title hides on empty workspaces and the pill shrinks to just the dots.
// Click a dot = go there, scroll = cycle. (Hover-peek comes with the popovers in Phase 3.)
Pill {
    id: root

    readonly property int count: 5
    readonly property int activeId: Hyprland.focusedWorkspace?.id ?? 1
    // The dots are workspaces 1–5; on 6–9 they slide along so the active one is the last dot.
    readonly property int firstId: Math.max(1, activeId - count + 1)
    readonly property int activeIndex: activeId - firstId

    // Focused window, only if it's on the focused workspace (an empty workspace has no title).
    readonly property HyprlandToplevel focusedWindow: {
        const t = Hyprland.activeToplevel
        return t && t.workspace && t.workspace === Hyprland.focusedWorkspace ? t : null
    }
    // Hyprland reports a workspace switch a moment before the new active window, so "no window" only
    // counts once it has lasted 60 ms; otherwise every switch would flash an empty pill.
    property HyprlandToplevel window: focusedWindow
    onFocusedWindowChanged: {
        if (focusedWindow) {
            settle.stop()
            window = focusedWindow
        } else {
            settle.restart()
        }
    }
    Timer {
        id: settle
        interval: 60
        onTriggered: root.window = root.focusedWindow
    }
    readonly property bool hasTitle: window !== null

    function workspace(id: int): HyprlandWorkspace {
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null
    }
    function go(id: int) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`)
    }

    property real padLeft: Theme.px(hasTitle ? 13 : 15)
    property real padRight: Theme.px(hasTitle ? 14 : 15)
    Behavior on padLeft { NumberAnimation { duration: Motion.pillWidth; easing.type: Motion.easeSmall } }
    Behavior on padRight { NumberAnimation { duration: Motion.pillWidth; easing.type: Motion.easeSmall } }
    readonly property real gap: Theme.px(12)
    implicitWidth: padLeft + dots.width + (hasTitle ? 2 * gap + 1 + title.targetWidth : 0) + padRight

    onScrolled: step => {
        // Cycle through the dots (wrapping), or step past them toward 6–9 once beyond 5.
        const next = activeId + step
        go(next < 1 ? Math.max(count, activeId) : next > Math.max(count, activeId) ? 1 : next)
    }

    // --- Dots. Each slot is 8 wide, the active one 18; slot widths animate so neighbours slide over.
    Item {
        id: dots
        x: root.padLeft
        anchors.verticalCenter: parent.verticalCenter
        width: (root.count - 1) * Theme.px(8 + 5) + Theme.px(18)
        height: Theme.px(8)

        readonly property real slotGap: Theme.px(5)
        // Left edge of slot i once the active capsule sits on `active`.
        function slotX(i: int, active: int): real {
            return i * Theme.px(8 + 5) + (i > active ? Theme.px(10) : 0)
        }

        Row {
            id: slots
            height: parent.height
            spacing: dots.slotGap

            Repeater {
                model: root.count
                Item {
                    id: slot
                    required property int index
                    readonly property int wsId: root.firstId + index
                    readonly property HyprlandWorkspace ws: root.workspace(wsId)
                    readonly property bool occupied: (ws?.toplevels.values.length ?? 0) > 0
                    readonly property bool urgent: ws?.urgent ?? false

                    width: index === root.activeIndex ? Theme.px(18) : Theme.px(8)
                    height: parent.height
                    Behavior on width {
                        enabled: !Motion.reduced
                        NumberAnimation { duration: Motion.wsCapsule; easing.type: Motion.easeSmall }
                    }

                    // Urgent halo: 3 px of tertiary at 25 % around the dot.
                    Rectangle {
                        anchors.centerIn: dot
                        width: dot.width + Theme.px(6)
                        height: width
                        radius: width / 2
                        color: Theme.alpha(Theme.secondary, 0.25)
                        opacity: slot.urgent ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Motion.micro } }
                    }
                    Rectangle {
                        id: dot
                        anchors.centerIn: parent
                        width: Theme.px(8)
                        height: width
                        radius: width / 2
                        color: slot.urgent ? Theme.secondary : slot.occupied ? Theme.alpha(Theme.text, 0.62) : "transparent"
                        border.width: slot.occupied || slot.urgent ? 0 : Theme.px(1.5)
                        border.color: Theme.alpha(Theme.text, 0.32)
                        Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
                    }

                    // Generous hit area: the full pill height and half the gap on each side.
                    MouseArea {
                        anchors.centerIn: parent
                        width: parent.width + dots.slotGap
                        height: root.height
                        onClicked: root.go(slot.wsId)
                    }
                }
            }
        }

        // The active capsule. Switching stretches its leading edge to the new dot first, then the
        // trailing edge lets go of the old one (03-MotionPills lane 1).
        Rectangle {
            id: capsule
            // Set by the switch animation below, not bound: a binding would jump to the new dot first.
            property real leftEdge
            property real rightEdge
            Component.onCompleted: {
                leftEdge = dots.slotX(root.activeIndex, root.activeIndex)
                rightEdge = leftEdge + Theme.px(18)
            }
            x: leftEdge
            width: rightEdge - leftEdge
            height: parent.height
            radius: height / 2
            color: Theme.accent
        }

        property int lastIndex: root.activeIndex
        Connections {
            target: root
            function onActiveIndexChanged() {
                const to = dots.slotX(root.activeIndex, root.activeIndex)
                const forward = root.activeIndex > dots.lastIndex
                dots.lastIndex = root.activeIndex
                if (Motion.reduced) {
                    capsuleMove.stop()
                    capsule.leftEdge = to
                    capsule.rightEdge = to + Theme.px(18)
                    return
                }
                lead.target = capsule; lead.property = forward ? "rightEdge" : "leftEdge"; lead.to = forward ? to + Theme.px(18) : to
                trail.target = capsule; trail.property = forward ? "leftEdge" : "rightEdge"; trail.to = forward ? to : to + Theme.px(18)
                capsuleMove.restart()
            }
        }
        SequentialAnimation {
            id: capsuleMove
            NumberAnimation { id: lead; duration: Motion.wsCapsule / 2; easing.type: Easing.OutCubic }
            NumberAnimation { id: trail; duration: Motion.wsCapsule / 2; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }
    }

    // --- 1 × 16 divider
    Rectangle {
        x: dots.x + dots.width + root.gap
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: Theme.px(16)
        color: Theme.white(0.16)
        opacity: root.hasTitle ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.wsTitle } }
    }

    // --- Focused window: app icon in accent + title (500, max 220 px with …). Focus changes cross-fade:
    //     the old title blurs out upward while the new one rises in. Title edits of the same window
    //     (e.g. nvim switching files) update in place.
    Item {
        id: title
        x: dots.x + dots.width + 2 * root.gap + 1
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.width - x - root.padRight)
        height: Theme.px(18)
        clip: true

        readonly property real targetWidth: current.implicitWidth
        property TitleLine current: a
        property string address: ""

        function update() {
            const w = root.window
            const addr = w?.address ?? ""
            if (addr === address) {
                if (w) current.set(w)
                return
            }
            address = addr
            const prev = current
            current = prev === a ? b : a
            if (w) current.set(w)
            prev.leave()
            if (w) current.enter()
        }

        Connections {
            target: root
            function onWindowChanged() { title.update() }
        }
        Connections {
            target: root.window
            function onTitleChanged() { title.update() }
        }
        Component.onCompleted: update()

        TitleLine { id: a }
        TitleLine { id: b; opacity: 0 }
    }

    // App icon by window class (the design's Lucide set); anything unknown gets a generic window.
    function iconFor(cls: string): string {
        cls = cls.toLowerCase()
        if (/kitty|foot|alacritty|wezterm|ghostty|terminal/.test(cls)) return "terminal"
        if (/discord|vesktop|webcord|element|telegram|signal|slack/.test(cls)) return "message-circle"
        if (/firefox|chrom|zen|librewolf|brave|vivaldi|browser/.test(cls)) return "globe"
        if (/steam|lutris|heroic|gamescope|^steam_app/.test(cls)) return "gamepad"
        if (/nautilus|thunar|dolphin|nemo|pcmanfm|files/.test(cls)) return "folder"
        if (/code|codium|zed/.test(cls)) return "code"
        return "app-window"
    }

    component TitleLine: Item {
        id: line
        property string text
        property string icon: "app-window"
        property real blur: 0
        implicitWidth: row.implicitWidth
        width: parent.width
        height: parent.height

        function set(w: HyprlandToplevel) {
            text = w.title
            icon = root.iconFor(w.wayland?.appId || w.lastIpcObject?.class || "")
        }
        function enter() { leaveAnim.stop(); enterAnim.restart() }
        function leave() { enterAnim.stop(); leaveAnim.restart() }

        Row {
            id: row
            height: parent.height
            spacing: Theme.px(7)
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: line.icon
                size: Theme.px(14)
                strokeWidth: line.icon === "terminal" ? 2.2 : 2
                color: Theme.accent
            }
            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: line.text
                font.weight: Font.Medium
                width: Math.min(implicitWidth, Theme.px(220))
            }
        }

        layer.enabled: blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: line.blur
            blurMax: Theme.px(8)
        }

        ParallelAnimation {
            id: enterAnim
            NumberAnimation { target: line; property: "opacity"; from: 0; to: 1; duration: Motion.wsTitle; easing.type: Motion.easeSmall }
            NumberAnimation { target: line; property: "y"; from: Theme.px(8); to: 0; duration: Motion.wsTitle; easing.type: Motion.easeSmall }
            NumberAnimation { target: line; property: "blur"; from: 1; to: 0; duration: Motion.wsTitle; easing.type: Motion.easeSmall }
        }
        ParallelAnimation {
            id: leaveAnim
            NumberAnimation { target: line; property: "opacity"; to: 0; duration: Motion.wsTitle; easing.type: Motion.easeSmall }
            NumberAnimation { target: line; property: "y"; to: -Theme.px(8); duration: Motion.wsTitle; easing.type: Motion.easeSmall }
            NumberAnimation { target: line; property: "blur"; to: 1; duration: Motion.wsTitle; easing.type: Motion.easeSmall }
        }
    }
}
