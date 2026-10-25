import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.services
import qs.components
import "../../components/apps.js" as Apps

// Workspace peek (DESIGN.md §3.1, 10-Popovers "Workspace peek"): hover a workspace dot for 400 ms.
// "Workspace 2 · 2 windows", a live preview of the workspace (wallpaper + each window where it sits) and
// its windows as rows; click a row to go to that window. Hover-only: it takes no keyboard focus.
Popover {
    id: root

    name: "peek"
    contentWidth: Theme.px(290)

    readonly property int wsId: Shell.peekId
    readonly property HyprlandWorkspace ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
    readonly property var windows: ws?.toplevels.values ?? []
    // Window positions (lastIpcObject) are only fresh after a refresh.
    onShownChanged: if (shown) Hyprland.refreshToplevels()
    onWsIdChanged: if (shown) Hyprland.refreshToplevels()

    function iconColor(icon: string): color {
        return icon === "globe" ? Theme.secondary : icon === "folder" ? Theme.good : Theme.accent
    }

    // --- Header: name + window count.
    Item {
        width: parent.width
        height: title.implicitHeight + Theme.px(4 + 8)
        Text {
            id: title
            x: Theme.px(6)
            y: Theme.px(4)
            text: "Workspace " + root.wsId
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.px(13.5)
            font.weight: Font.DemiBold
        }
        Text {
            anchors { right: parent.right; rightMargin: Theme.px(6); baseline: title.baseline }
            text: root.windows.length === 0 ? "Empty"
                : root.windows.length + (root.windows.length === 1 ? " window" : " windows")
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.px(11.5)
        }
    }

    // --- Preview, 120 px: the workspace's window area (below the pills) scaled to the preview's width over
    //     the wallpaper, top-aligned; the bottom is cut off like in the design. Windows are live captures, a
    //     plain tile until the first frame arrives.
    ClippingRectangle {
        id: preview
        width: parent.width
        height: Theme.px(120)
        radius: Theme.px(12)
        color: Qt.darker(Theme.glassTint, 1.2)

        readonly property real reserved: Theme.px(48)
        readonly property real areaW: root.width
        readonly property real areaH: root.height - reserved
        readonly property real k: (width - Theme.px(12)) / areaW
        readonly property real ox: Theme.px(6)
        readonly property real oy: Theme.px(6) - Theme.px(12) * k   // the 12 px window gap is inside the area
        readonly property real monX: root.ws?.monitor?.x ?? 0
        readonly property real monY: root.ws?.monitor?.y ?? 0

        Image {
            anchors.fill: parent
            source: Theme.wallpaper ? "file://" + Theme.wallpaper : ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.7
        }

        Repeater {
            model: root.windows
            WindowPreview {
                required property HyprlandToplevel modelData
                toplevel: modelData
                k: preview.k
                ox: preview.ox
                oy: preview.oy
                monX: preview.monX
                monY: preview.monY
                reserved: preview.reserved
                live: root.shown
                showLabel: false
            }
        }
    }

    // --- Windows: app icon + title. Click = go there.
    Item { width: 1; height: root.windows.length > 0 ? Theme.px(6) : 0 }
    Repeater {
        model: root.windows
        MenuRow {
            required property HyprlandToplevel modelData
            width: parent.width
            icon: Apps.iconFor(Apps.classOf(modelData))
            iconColor: root.iconColor(icon)
            text: modelData.title
            label.font.pixelSize: Theme.px(12.5)
            onClicked: {
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${modelData.address}" })`)
                Shell.closePopover()
            }
        }
    }
}
