import QtQuick
import qs.services
import qs.components

// Control Center (DESIGN.md §3.4, 16-Control, 17-ControlPages): Super+A or a click on the status pill.
// A 410 px panel under the status pill, right-aligned to the screen inset; the pill stays lit. It grows
// out of the pill (01-MotionControl: droplet over the pill, short neck, springs into the panel; content
// fades up once the shape is 60 % done) and snaps back on close.
// Sub-pages (Sound, Wi-Fi & Bluetooth) push in from the right while the main page slides left and fades,
// and the panel's height springs to fit (04-MotionOverlays, Control Center frame). Esc goes back a level:
// tray menu → sub-page → night-light card → closed.
// Pages share one small interface: key(event) → handled, plus `cc` pointing here.
Item {
    id: root

    required property Item pill
    property string screenName
    anchors.fill: parent

    readonly property bool shown: Shell.panel === "control" && (Shell.panelScreen === "" || Shell.panelScreen === screenName)
    readonly property alias body: panel.body
    readonly property alias dimLevel: panel.dimLevel
    readonly property bool active: panel.visible
    readonly property string page: Shell.controlPage
    // Room for a page's content, so long lists scroll instead of running off the screen.
    readonly property real maxContentHeight: height - panel.finalY - Theme.px(12) - 2 * panel.padding

    function refocus() { panel.forceActiveFocus() }

    // Push progress: 0 = main page, 1 = sub-page. The sub-page stays loaded while it slides back out.
    property real push: page === "" ? 0 : 1
    Behavior on push {
        enabled: panel.opened
        NumberAnimation { duration: Motion.fixed(Motion.push); easing.type: Motion.easeSmall }
    }
    property string subPage: ""
    onPageChanged: {
        if (page !== "") subPage = page
        Shell.controlTray = null
        refocus()
    }
    onPushChanged: if (push === 0 && page === "") subPage = ""
    readonly property real slide: Motion.reduced ? 0 : 1   // reduced motion cross-fades without sliding

    // Tiles arrive one after another once the content shows.
    readonly property bool revealed: shown && panel.p >= 0.6
    onRevealedChanged: if (revealed) main.enter(!Motion.reduced)
    // Wi-Fi scans while it's open (scanned networks drop out of the list once scanning stops, so that waits
    // until the panel is gone). Closed all the way: next time it opens on the main page.
    onShownChanged: if (shown) {
        main.reset()
        Network.setScanning(true)
    }
    onActiveChanged: if (!active && !shown) {
        Network.setScanning(false)
        Shell.controlPage = ""
        Shell.controlExpand = ""
    }

    function key(event: var): bool {
        // Shift+Tab arrives as Backtab from a keyboard but as Tab + Shift from synthetic input; pages only
        // look at Backtab.
        const back = event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)
        const e = { key: back ? Qt.Key_Backtab : event.key, modifiers: event.modifiers }
        if (Shell.controlTray) return tray.key(e)
        const current = page === "" ? main : sub.item
        if (current?.key(e)) return true
        if (e.key === Qt.Key_Escape || (e.key === Qt.Key_Backspace && page !== "")) {
            if (page !== "") Shell.controlPage = ""
            else if (Shell.controlExpand !== "") Shell.controlExpand = ""
            else Shell.close("control")
            return true
        }
        return false
    }

    Panel {
        id: panel
        pill: root.pill
        shown: root.shown
        openMs: Motion.controlIn
        closeMs: Motion.controlOut
        finalWidth: Theme.px(410)
        finalX: width - Theme.px(12) - finalWidth
        finalY: Theme.px(58)
        finalRadius: Theme.px(26)
        padding: Theme.px(14)

        // MotionControl.dc.html ccBlob, 10 % pill → 15 % droplet → 22 % overshoot → 26 % panel: the droplet
        // keeps the pill's top, 16 px narrower and 2.5× taller; the overshoot is 8 px out on the left, 4 up,
        // 12 wider and 14 taller.
        dropT: 0.31
        overT: 0.75
        dropW: start.width - Theme.px(16)
        dropH: start.height * 2.5
        dropDy: 0
        dropR: Theme.px(30)
        overDx: -Theme.px(8)
        overDy: -Theme.px(4)
        overW: Theme.px(12)
        overH: Theme.px(14)
        overR: Theme.px(30)
        neckWidth: Theme.px(80)

        Keys.onPressed: e => { if (root.key(e)) e.accepted = true }

        Item {
            id: stack
            width: parent.width
            implicitHeight: root.page === "" || !sub.item ? main.implicitHeight : sub.item.implicitHeight

            MainPage {
                id: main
                cc: root
                width: parent.width
                x: -0.6 * width * root.push * root.slide
                opacity: 1 - root.push
                visible: opacity > 0
                enabled: root.page === ""
            }
            Loader {
                id: sub
                width: parent.width
                x: 0.7 * width * (1 - root.push) * root.slide
                opacity: root.push
                visible: opacity > 0
                active: root.subPage !== ""
                source: root.subPage === "sound" ? "SoundPage.qml" : root.subPage === "network" ? "NetworkPage.qml" : ""
                onLoaded: { item.cc = root; item.width = Qt.binding(() => sub.width) }
            }

            // A click next to an open tray menu closes it.
            MouseArea {
                anchors.fill: parent
                visible: tray.shown
                onPressed: Shell.controlTray = null
            }
            TrayMenu {
                id: tray
                anchorItem: Shell.controlTray ? main.trayButton(Shell.controlTray) : null
            }
        }
    }
}
