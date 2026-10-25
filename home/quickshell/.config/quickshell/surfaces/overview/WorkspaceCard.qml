import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.services
import qs.components

// One card of the overview (11-Overview, Overview.dc.html `.card`): a workspace's whole monitor scaled down,
// the wallpaper behind live captures of its windows. Empty workspaces are a dashed outline with "empty";
// the scratchpad is a glass card with its window floating in the middle. The selected card has a 2 px
// accent edge and a 5 px accent 18 % halo; the selected window inside it the accent edge too.
// Width / height are animated by the overview (it zooms out of / into the screen), so everything inside
// scales from the card's size; `zoom` (0 = full screen, 1 = in its slot) fades the card's own chrome.
Item {
    id: root

    property HyprlandWorkspace ws: null
    property bool scratchpad: false
    property var windows: []
    property bool selected: false
    property string selectedWindow: ""   // address (no 0x) of the selected window
    property string query: ""            // the filter; non-matching windows dim
    property bool live: true
    property real zoom: 1
    property real monW: 1                // the monitor's logical size the card stands for
    property real monH: 1

    readonly property bool empty: windows.length === 0
    readonly property real r: Theme.px(14) * zoom

    function matches(w: HyprlandToplevel): bool {
        if (query === "") return true
        const q = query.toLowerCase()
        return w.title.toLowerCase().includes(q) || (w.wayland?.appId ?? "").toLowerCase().includes(q)
    }
    readonly property bool anyMatch: query === "" || windows.some(w => matches(w))
    opacity: anyMatch ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }

    // Halo + accent edge (selected), under the card.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Theme.px(5) - Theme.px(2)
        radius: root.r + Theme.px(7)
        color: "transparent"
        border.width: Theme.px(5)
        border.color: Theme.alpha(Theme.accent, 0.18)
        visible: root.selected
        opacity: root.zoom
    }
    RectangularShadow {
        anchors.fill: parent
        visible: !root.empty || root.scratchpad
        radius: root.r
        offset.y: Theme.px(14)
        blur: Theme.px(40)
        color: Qt.rgba(0, 0, 0, root.selected ? 0.45 : 0.4)
        opacity: root.zoom
    }

    // --- Workspace with windows: wallpaper + the windows where they sit.
    ClippingRectangle {
        id: body
        anchors.fill: parent
        visible: !root.scratchpad && !root.empty
        radius: root.r
        color: Qt.darker(Theme.glassTint, 1.2)

        readonly property real k: width / root.monW
        Image {
            anchors.fill: parent
            source: Theme.wallpaper ? "file://" + Theme.wallpaper : ""
            sourceSize: Qt.size(root.monW, root.monH)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Repeater {
            model: root.scratchpad ? [] : root.windows
            WindowPreview {
                required property HyprlandToplevel modelData
                toplevel: modelData
                k: body.k
                monX: root.ws?.monitor?.x ?? 0
                monY: root.ws?.monitor?.y ?? 0
                live: root.live
                selected: root.selectedWindow === modelData.address
                dimmed: !root.matches(modelData)
            }
        }
    }

    // --- Empty: dashed white 28 % outline over white 4 %.
    Rectangle {
        anchors.fill: parent
        visible: root.empty && !root.scratchpad
        radius: root.r
        color: Theme.white(0.04)
    }
    Shape {
        anchors.fill: parent
        visible: root.empty && !root.scratchpad
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.white(0.28)
            strokeWidth: Theme.px(1.5)
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 3]
            fillColor: "transparent"
            PathRectangle { x: 1; y: 1; width: root.width - 2; height: root.height - 2; radius: root.r }
        }
    }
    Text {
        anchors.centerIn: parent
        visible: root.empty && !root.scratchpad
        text: "empty"
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.px(13)
    }

    // --- Scratchpad: glass card, its window centred near the top (280 × 130), a note at the bottom.
    GlassRect {
        anchors.fill: parent
        visible: root.scratchpad
        variant: "panel"
        radius: root.r
    }
    Repeater {
        model: root.scratchpad ? root.windows.slice(0, 1) : []
        WindowPreview {
            required property HyprlandToplevel modelData
            toplevel: modelData
            x: (root.width - width) / 2
            y: Theme.px(12)
            width: Theme.px(280)
            height: Theme.px(130)
            live: root.live
            selected: root.selectedWindow === modelData.address
            dimmed: !root.matches(modelData)
        }
    }
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.px(22) }
        visible: root.scratchpad
        text: root.empty ? "empty · Super S starts a terminal" : "floats above every workspace"
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.px(12)
    }

    // Accent edge on top of the content.
    Rectangle {
        anchors.fill: parent
        radius: root.r
        color: "transparent"
        visible: root.selected || (!root.empty && !root.scratchpad)
        border.width: root.selected ? Theme.px(2) : 1
        border.color: root.selected ? Theme.accent : Theme.white(0.16)
        opacity: root.zoom
    }
}
