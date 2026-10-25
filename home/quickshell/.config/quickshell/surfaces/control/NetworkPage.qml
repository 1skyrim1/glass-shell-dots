import QtQuick
import QtQuick.Shapes
import qs.services
import qs.components
import qs.surfaces.launcher

// The shared Wi-Fi & Bluetooth page (16-Control left, 17-ControlPages): networks, then Bluetooth devices,
// opened at the section whose › was pressed. A secured network grows its row into a password field
// (no extra window); a wrong password keeps it open with the text selected. S scans for Bluetooth
// devices (new ones come in at the top); pairing shows the code in the device's row.
// The header switch turns the radio of the section the keys are in on or off.
Column {
    id: root

    property Item cc

    // The rows only change when networks come or go (or one connects), not on every signal-strength change:
    // a new array would rebuild every row, and an open password field with them. While a password row is
    // open the order holds still.
    property var nets: []
    function refresh() {
        const live = Network.enabled ? Network.networks : []
        const key = a => a.map(n => n.name + (n.connected ? "*" : "")).join("\n")
        if (openNet !== "") {
            // Keep the order; only drop networks that are gone and add new ones at the end.
            const next = nets.filter(n => live.includes(n)).concat(live.filter(n => !nets.includes(n)))
            if (key(next) !== key(nets)) nets = next
        } else if (key(live) !== key(nets)) {
            nets = live
        }
    }
    readonly property var liveNets: Network.networks
    onLiveNetsChanged: refresh()
    onOpenNetChanged: refresh()
    Component.onCompleted: refresh()
    readonly property var devs: Bt.enabled ? Bt.devices : []
    readonly property int count: nets.length + devs.length
    property int cursor: 0
    readonly property bool inBluetooth: cursor >= nets.length && (devs.length > 0 || Shell.controlSection === "bluetooth")
    readonly property var currentNet: !inBluetooth ? nets[cursor] ?? null : null
    readonly property var currentDev: inBluetooth ? devs[cursor - nets.length] ?? null : null

    property string openNet: ""   // the network whose password row is open

    function startAt(section: string) {
        cursor = section === "bluetooth" ? nets.length : 0
        Qt.callLater(() => list.contentY = section === "bluetooth" ? Math.max(0, Math.min(btLabel.y, list.contentHeight - list.height)) : 0)
    }
    // The pairing agent only while the page is up (Wi-Fi scans while the Control Center is open, so the
    // list is ready by the time this page shows).
    onVisibleChanged: {
        Bt.agentWanted = visible
        if (visible) startAt(Shell.controlSection)
        else { Bt.setScanning(false); openNet = ""; Network.clearError() }
    }
    Component.onDestruction: { Bt.setScanning(false); Bt.agentWanted = false }
    Connections {
        target: Shell
        function onControlSectionChanged() { if (root.visible) root.startAt(Shell.controlSection) }
    }

    // Keep the row with the keys on in view.
    onCursorChanged: Qt.callLater(() => {
        const r = (inBluetooth ? devRepeater.itemAt(cursor - nets.length) : netRepeater.itemAt(cursor))
        if (!r) return
        const y = r.mapToItem(content, 0, 0).y
        if (y < list.contentY) list.contentY = y - Theme.px(30)
        else if (y + r.height > list.contentY + list.height) list.contentY = y + r.height - list.height
        list.contentY = Math.max(0, Math.min(list.contentY, list.contentHeight - list.height))
    })

    function activateNet(n: var) {
        if (!n || n.connected) return
        if (Network.secured(n) && !n.known && !Network.enterprise(n)) {
            Network.clearError()
            openNet = n.name
        } else if (Network.enterprise(n) && !n.known) {
            Network.failedName = n.name
            Network.failText = n.name + " needs an 802.1X profile (set it up with nmtui once)"
        } else {
            Network.connect(n, "")
        }
    }

    function key(e: var): bool {
        const k = e.key
        if (k === Qt.Key_J || k === Qt.Key_Down || k === Qt.Key_Tab) { if (count) cursor = (cursor + 1) % count; return true }
        if (k === Qt.Key_K || k === Qt.Key_Up || k === Qt.Key_Backtab) { if (count) cursor = (cursor - 1 + count) % count; return true }
        if (k === Qt.Key_S) { Bt.setScanning(!Bt.scanning); return true }
        if (k === Qt.Key_F) {
            if (currentNet?.known) Network.forget(currentNet)
            else if (currentDev) Bt.forget(currentDev)
            return true
        }
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            if (currentDev === Bt.pairingDevice && Bt.needsConfirm) Bt.confirm()
            else if (currentNet) activateNet(currentNet)
            else if (currentDev) Bt.activate(currentDev)
            return true
        }
        return false
    }

    PageHeader {
        title: "Wi-Fi & Bluetooth"
        hasSwitch: true
        checked: root.inBluetooth ? Bt.enabled : Network.enabled
        onBack: Shell.controlPage = ""
        onToggled: root.inBluetooth ? Bt.toggle() : Network.toggle()
    }

    Flickable {
        id: list
        width: parent.width
        height: Math.min(content.implicitHeight, Math.max(Theme.px(200), (root.cc?.maxContentHeight ?? 1000) - Theme.px(40) - hints.implicitHeight))
        contentHeight: content.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        Behavior on contentY { enabled: !Motion.reduced; NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }

        Column {
            id: content
            width: list.width

            SectionLabel { text: "Networks"; above: Theme.px(12); below: Theme.px(6); leftPadding: Theme.px(4) }
            OffRow { visible: !Network.enabled; text: "Wi-Fi is off" }
            Repeater {
                id: netRepeater
                model: root.nets
                NetRow {}
            }
            ErrorLine {
                visible: Network.failText !== "" && !root.nets.some(n => n.name === Network.failedName && root.openNet === n.name)
                text: Network.failText
            }

            Item {
                id: btLabel
                width: parent.width
                height: btText.height
                SectionLabel { id: btText; text: "Bluetooth"; above: Theme.px(12); below: Theme.px(6); leftPadding: Theme.px(4); width: implicitWidth }
                Row {
                    visible: Bt.scanning
                    anchors { left: btText.right; leftMargin: Theme.px(4); verticalCenter: btText.verticalCenter; verticalCenterOffset: Theme.px(3) }
                    spacing: Theme.px(6)
                    Spinner { anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Searching…"
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.px(11.5)
                    }
                }
                KeyHint {
                    anchors { right: parent.right; rightMargin: Theme.px(4); verticalCenter: btText.verticalCenter; verticalCenterOffset: Theme.px(3) }
                    key: "S scan"
                }
            }
            OffRow { visible: !Bt.enabled; text: "Bluetooth is off" }
            OffRow { visible: Bt.enabled && root.devs.length === 0 && !Bt.scanning; text: "No devices yet · S searches for new ones" }
            Repeater {
                id: devRepeater
                model: root.devs
                DevRow {}
            }
        }
    }

    HintBar {
        id: hints
        above: Theme.px(10)
        hints: root.inBluetooth ? [["Enter", "connect"], ["F", "forget"], ["S", "scan"]]
                                : [["J K", "move"], ["Enter", "connect"], ["F", "forget"], ["Esc", "back"]]
    }

    // --- Pieces

    component OffRow: Text {
        width: parent.width
        leftPadding: Theme.px(12)
        topPadding: Theme.px(8)
        bottomPadding: Theme.px(8)
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.px(13)
    }

    component ErrorLine: Text {
        width: parent.width
        leftPadding: Theme.px(12)
        rightPadding: Theme.px(12)
        topPadding: Theme.px(8)
        color: Theme.error
        font.family: Theme.font
        font.pixelSize: Theme.px(12)
        wrapMode: Text.WordWrap
    }

    // The "Searching…" spinner (ControlPages.dc.html): r9 in a 24 box, 3 wide, a quarter arc in accent
    // going round a 30 % ring.
    component Spinner: Item {
        id: spinner
        readonly property real u: width / 24
        width: Theme.px(13)
        height: width
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.alpha(Theme.accent, 0.3)
                strokeWidth: 3 * spinner.u
                fillColor: "transparent"
                PathAngleArc { centerX: 12 * spinner.u; centerY: 12 * spinner.u; radiusX: 9 * spinner.u; radiusY: 9 * spinner.u; sweepAngle: 360 }
            }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.accent
                strokeWidth: 3 * spinner.u
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathAngleArc { centerX: 12 * spinner.u; centerY: 12 * spinner.u; radiusX: 9 * spinner.u; radiusY: 9 * spinner.u; startAngle: -90; sweepAngle: 90 }
            }
            RotationAnimation on rotation { from: 0; to: 360; duration: Motion.spinner; loops: Animation.Infinite; running: spinner.visible }
        }
    }

    // The tinted box a row grows into (password, pairing): accent 16 % + 1 px accent 35 %, radius 14.
    component Grown: Rectangle {
        radius: Theme.px(14)
        color: Theme.alpha(Theme.accent, 0.16)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.35)
    }

    component PillButton: Button {
        id: pillButton
        property string text
        property bool primary: false
        property bool muted: false   // "Waiting…": full opacity, faint text (not the 45 % disabled look)
        height: Theme.px(38)
        hoverScale: 1.02
        base: primary ? Theme.accent : Theme.white(0.08)
        Text {
            anchors.centerIn: parent
            text: pillButton.text
            color: pillButton.primary ? Theme.textOnAccent : pillButton.muted ? Theme.textFaint : Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.px(13)
            font.weight: pillButton.primary ? Font.DemiBold : Font.Normal
        }
    }

    // A network; secured ones grow a password field in place.
    component NetRow: Item {
        id: net
        required property var modelData
        required property int index
        readonly property bool expanded: root.openNet === modelData.name
        readonly property bool failed: Network.failedName === modelData.name && Network.failText !== ""
        width: content.width
        implicitHeight: expanded ? box.height : row.height
        clip: true
        Behavior on implicitHeight { enabled: !Motion.reduced; NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }

        // Joined: the row closes again.
        readonly property bool connected: modelData.connected
        onConnectedChanged: if (connected && expanded) { root.openNet = ""; root.cc?.refocus() }
        onExpandedChanged: if (expanded) Qt.callLater(() => { field.text = ""; field.forceActiveFocus() })
        onFailedChanged: if (failed && expanded) { field.selectAll(); field.forceActiveFocus() }

        Grown {
            id: box
            width: parent.width
            height: Theme.px(4) + row.height + column.implicitHeight + Theme.px(12)
            opacity: net.expanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
        }

        ListRow {
            id: row
            y: net.expanded ? Theme.px(4) : 0
            width: parent.width
            icon: Network.iconOf(net.modelData)
            text: net.modelData.name
            bold: net.expanded
            selected: root.cursor === net.index && !net.expanded
            note: net.modelData.connected ? "Connected"
                : net.modelData.stateChanging ? "Connecting…"
                : net.expanded ? Network.securityLabel(net.modelData)
                : !Network.secured(net.modelData) ? "open" : ""
            noteColor: net.modelData.connected ? Theme.accent : Theme.textFaint
            onClicked: { root.cursor = net.index; root.activateNet(net.modelData) }
            Icon {
                visible: Network.secured(net.modelData) && !net.modelData.known && !net.expanded && !net.modelData.connected
                anchors.verticalCenter: parent.verticalCenter
                name: "lock"
                size: Theme.px(13)
                color: Theme.textFaint
            }
            Behavior on y { enabled: !Motion.reduced; NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
        }

        Column {
            id: column
            y: row.y + row.height
            x: Theme.px(12)
            width: parent.width - Theme.px(24)
            spacing: Theme.px(10)
            opacity: net.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }

            Rectangle {
                width: parent.width
                height: Theme.px(40)
                radius: Theme.px(12)
                color: Theme.alpha(Theme.scrim, 0.35)
                border.width: Theme.px(1.5)
                border.color: net.failed ? Theme.error : Theme.accent

                TextInput {
                    id: field
                    anchors { left: parent.left; leftMargin: Theme.px(12); right: eye.left; rightMargin: Theme.px(8); verticalCenter: parent.verticalCenter }
                    property bool reveal: false
                    echoMode: reveal ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    color: Theme.text
                    selectionColor: Theme.alpha(Theme.accent, 0.35)
                    selectedTextColor: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.px(reveal ? 14 : 12)
                    font.letterSpacing: reveal ? 0 : Theme.px(2)
                    clip: true
                    enabled: net.expanded
                    cursorDelegate: Rectangle { width: 2; radius: 1; color: Theme.accent; visible: field.cursorVisible }
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (text !== "") Network.connect(net.modelData, text) }
                        else if (e.key === Qt.Key_Escape) { root.openNet = ""; Network.clearError(); root.cc?.refocus() }
                        else return
                        e.accepted = true
                    }
                }
                Icon {
                    id: eye
                    anchors { right: parent.right; rightMargin: Theme.px(12); verticalCenter: parent.verticalCenter }
                    name: field.reveal ? "eye-off" : "eye"
                    size: Theme.px(16)
                    color: Theme.textFaint
                    MouseArea { anchors.fill: parent; anchors.margins: -Theme.px(6); onClicked: field.reveal = !field.reveal }
                }
            }
            ErrorLine {
                visible: net.failed
                leftPadding: Theme.px(2)
                topPadding: 0
                text: Network.failText
            }
            Row {
                width: parent.width
                spacing: Theme.px(8)
                PillButton {
                    width: (parent.width - parent.spacing) / 2
                    text: "Cancel"
                    onClicked: { root.openNet = ""; Network.clearError(); root.cc?.refocus() }
                }
                PillButton {
                    width: (parent.width - parent.spacing) / 2
                    text: net.modelData.stateChanging ? "Connecting…" : "Connect"
                    primary: true
                    enabled: field.text !== "" && !net.modelData.stateChanging
                    onClicked: Network.connect(net.modelData, field.text)
                }
            }
        }
    }

    // A Bluetooth device; the one being paired shows the code.
    component DevRow: Item {
        id: dev
        required property var modelData
        required property int index
        readonly property bool pairing: Bt.pairingDevice === modelData
        readonly property bool keyboard: Bt.iconOf(modelData) === "keyboard"
        width: content.width
        implicitHeight: pairing ? box.height : row.height
        clip: true
        Behavior on implicitHeight { enabled: !Motion.reduced; NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }

        // New devices slide in from the top.
        Component.onCompleted: if (!modelData.paired) slide.start()
        NumberAnimation { id: slide; target: dev; property: "opacity"; from: 0; to: 1; duration: Motion.small; easing.type: Motion.easeSmall }

        Grown {
            id: box
            width: parent.width
            height: Theme.px(4) + row.height + column.implicitHeight + Theme.px(12)
            opacity: dev.pairing ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
        }

        ListRow {
            id: row
            y: dev.pairing ? Theme.px(4) : 0
            width: parent.width
            icon: Bt.iconOf(dev.modelData)
            text: dev.modelData.name
            bold: dev.pairing
            selected: root.cursor === root.nets.length + dev.index && !dev.pairing
            note: dev.modelData.connected ? "Connected" + (Bt.batteryOf(dev.modelData) !== "" ? " · " + Bt.batteryOf(dev.modelData) : "")
                : dev.modelData.paired ? "Paired" : "new"
            noteColor: dev.modelData.connected ? Theme.accent : Theme.textFaint
            onClicked: { root.cursor = root.nets.length + dev.index; Bt.activate(dev.modelData) }
        }

        Column {
            id: column
            y: row.y + row.height
            x: Theme.px(12)
            width: parent.width - Theme.px(24)
            spacing: Theme.px(10)
            visible: dev.pairing
            Text {
                width: parent.width
                topPadding: Theme.px(2) - parent.spacing
                text: Bt.needsConfirm ? "Check that " + dev.modelData.name + " shows this code, then confirm:"
                    : Bt.pairCode === "" ? "Pairing…"
                    : dev.keyboard ? "Type this code on the keyboard, then press Enter on it:"
                    : "Enter this code on " + dev.modelData.name + ":"
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.px(12.5)
                lineHeight: Theme.px(18)
                lineHeightMode: Text.FixedHeight
                wrapMode: Text.WordWrap
            }
            Text {
                visible: Bt.pairCode !== ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                // "482 913"
                text: Bt.pairCode.length === 6 ? Bt.pairCode.slice(0, 3) + " " + Bt.pairCode.slice(3) : Bt.pairCode
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.px(22)
                font.weight: Font.Medium
                font.letterSpacing: Theme.px(2)
            }
            Row {
                width: parent.width
                spacing: Theme.px(8)
                topPadding: Theme.px(2)
                PillButton {
                    width: (parent.width - parent.spacing) / 2
                    text: "Cancel"
                    onClicked: Bt.cancelPair()
                }
                PillButton {
                    width: (parent.width - parent.spacing) / 2
                    text: Bt.needsConfirm ? "Pair" : "Waiting…"
                    primary: Bt.needsConfirm
                    muted: !Bt.needsConfirm
                    onClicked: Bt.confirm()
                }
            }
        }
    }
}
