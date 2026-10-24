import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import qs.services
import qs.components
import qs.surfaces.launcher

// The Control Center's main page (16-Control): battery header with the config / power buttons, Wi-Fi and
// Bluetooth tiles, six small toggles, volume and brightness, the media card, power profile and the
// background apps (tray).
// Keys: rows top to bottom (Tab / Shift+Tab, ↑ ↓), ← → inside a row or on a slider, Enter opens (a page, the
// night-light card, a tray menu), Space toggles, 1–8 toggle the tiles, P cycles the power profile.
Column {
    id: root

    property Item cc   // the ControlCenter

    // --- Keyboard position: row and column. Starts on the Wi-Fi tile (16-Control shows it focused).
    readonly property var rows: ["header", "wide", "small1", "small2", "volume", "brightness"]
        .concat(Media.player ? ["media"] : [], ["profile"], trayItems.length > 0 ? ["tray"] : [])
    property int row: 1
    property int col: 0
    readonly property string at: rows[Math.min(row, rows.length - 1)]
    function focusedOn(r: string, c: int): bool { return at === r && col === c }
    function reset() { row = nightExpanded ? 2 : 1; col = 0 }
    function colsIn(r: string): int {
        return ({ header: 2, wide: 2, small1: 3, small2: 3, media: 3, profile: 3, tray: trayItems.length })[r] ?? 1
    }
    function moveRow(d: int) {
        row = (row + d + rows.length) % rows.length
        col = Math.min(col, colsIn(at) - 1)
    }

    readonly property var trayItems: SystemTray.items.values
    // The icon a tray item's menu grows from.
    function trayButton(item: var): Item { return trayRepeater.itemAt(trayItems.indexOf(item)) }
    readonly property bool nightExpanded: Shell.controlExpand === "nightlight"
    onNightExpandedChanged: if (nightExpanded) { row = rows.indexOf("small1"); col = 0 }   // ← → move its slider

    // --- Actions
    function toggleTile(n: int) {
        switch (n) {
        case 1: Network.toggle(); break
        case 2: Bt.toggle(); break
        case 3: NightLight.toggle(); break
        case 4: Modes.dnd ? (Modes.dnd = false) : Modes.setDnd("manual"); break
        case 5: Modes.gameMode = !Modes.gameMode; break
        case 6: Modes.keepAwake = !Modes.keepAwake; break
        case 7: Audio.toggleMicMute(); break
        case 8: Network.setAirplane(!Network.airplane); break
        }
    }
    function openNetwork(section: string) {
        Shell.controlSection = section
        Shell.controlPage = "network"
    }
    function toggleNightCard() { Shell.controlExpand = nightExpanded ? "" : "nightlight" }
    function openTray(i: int) {
        const item = trayItems[i]
        if (!item) return
        if (item.hasMenu) Shell.controlTray = item
        else item.activate()
    }
    function editConfig() {
        Quickshell.execDetached(["kitty", "-e", "nvim", Quickshell.shellDir + "/config.json"])
        Shell.closeAll()
    }
    readonly property var profiles: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
    function setProfile(i: int) {
        const p = profiles[Math.max(0, Math.min(2, i))]
        if (p === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile) return
        PowerProfiles.profile = p
    }
    function cycleProfile() {
        const n = PowerProfiles.hasPerformanceProfile ? 3 : 2
        setProfile((profiles.indexOf(PowerProfiles.profile) + 1) % n)
    }

    // The key handler the Control Center calls; true = handled.
    function key(e: var): bool {
        const k = e.key, a = at
        if (e.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) return false
        if (k >= Qt.Key_1 && k <= Qt.Key_8) { toggleTile(k - Qt.Key_0); return true }
        if (k === Qt.Key_P) { cycleProfile(); return true }
        if (k === Qt.Key_Tab || k === Qt.Key_Down || k === Qt.Key_J) { moveRow(1); return true }
        if (k === Qt.Key_Backtab || k === Qt.Key_Up || k === Qt.Key_K) { moveRow(-1); return true }
        if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_H || k === Qt.Key_L) {
            const d = k === Qt.Key_Left || k === Qt.Key_H ? -1 : 1
            if (a === "volume") volume.slider.nudge(d)
            else if (a === "brightness") brightness.slider.nudge(d)
            else if (a === "profile") { setProfile(profiles.indexOf(PowerProfiles.profile) + d) }
            else if (a === "small1" && col === 0 && nightExpanded) nightCard.nudge(d)
            else col = Math.max(0, Math.min(colsIn(a) - 1, col + d))
            return true
        }
        if (k === Qt.Key_Space) {
            if (a === "wide") toggleTile(col + 1)
            else if (a === "small1" || a === "small2") toggleTile((a === "small1" ? 3 : 6) + col)
            else if (a === "media") Media.toggle()
            else return false
            return true
        }
        if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            if (a === "header") col === 0 ? editConfig() : Shell.open("power")
            else if (a === "wide") openNetwork(col === 0 ? "wifi" : "bluetooth")
            else if (a === "small1" && col === 0) toggleNightCard()
            else if (a === "small1" || a === "small2") toggleTile((a === "small1" ? 3 : 6) + col)
            else if (a === "volume") Shell.controlPage = "sound"
            else if (a === "media") [Media.previous, Media.toggle, Media.next][col]()
            else if (a === "tray") openTray(col)
            else return false
            return true
        }
        return false
    }

    // --- Stagger: tiles and rows arrive one after another once the content shows.
    function enter(run: bool) {
        for (const t of [wifi, bluetooth].concat(grid.tiles)) t.enter(run)
    }

    // --- Header: battery, time left, config + power buttons
    Item {
        width: parent.width
        height: Theme.px(48)

        Row {
            x: Theme.px(4)
            y: Theme.px(2)
            height: Theme.px(34)
            spacing: Theme.px(10)

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(22)
                height: batt.height
                Icon { id: batt; anchors.centerIn: parent; name: "battery"; size: Theme.px(16) }
                Rectangle {
                    readonly property real unit: batt.size / 24
                    x: batt.x + 5 * unit
                    y: batt.y + 9 * unit
                    width: Math.max(3, 14 * Battery.percent / 100) * unit
                    height: 6 * unit
                    radius: unit
                    color: Battery.charging ? Theme.good : Theme.text
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: Battery.present ? Battery.percent + " %" : "Plugged in"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.px(14)
                    font.weight: Font.DemiBold
                }
                Text {
                    readonly property int full: Math.round((Battery.device?.timeToFull ?? 0) / 60)
                    function span(m: int): string { return m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min" }
                    visible: Battery.present
                    text: Battery.device?.state === UPowerDeviceState.FullyCharged ? "fully charged"
                        : Battery.charging ? "charging" + (full > 0 ? " · " + span(full) + " to full" : "")
                        : Battery.minutesLeft > 0 ? "about " + span(Battery.minutesLeft) + " left" : "on battery"
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.px(11.5)
                }
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: Theme.px(4); top: parent.top; topMargin: Theme.px(2) }
            spacing: Theme.px(6)
            Repeater {
                model: [{ icon: "sliders", act: () => root.editConfig() }, { icon: "power", act: () => Shell.open("power") }]
                Button {
                    id: headerButton
                    required property var modelData
                    required property int index
                    width: Theme.px(34)
                    height: width
                    base: Theme.white(0.08)
                    focused: root.focusedOn("header", index)
                    onClicked: modelData.act()
                    Icon { anchors.centerIn: parent; name: headerButton.modelData.icon; size: Theme.px(16) }
                }
            }
        }
    }

    // --- Wi-Fi and Bluetooth: body toggles, › opens the shared page at that section.
    Row {
        width: parent.width
        spacing: Theme.px(8)
        Tile {
            id: wifi
            wide: true
            width: (parent.width - parent.spacing) / 2
            height: Theme.px(62)
            order: 0
            number: "1"
            icon: Network.bars > 0 ? Network.iconOf(Network.network) : Network.enabled ? "wifi" : "wifi-off"
            title: "Wi-Fi"
            on: Network.enabled
            subtitle: !Network.enabled ? "Off" : Network.network?.name ?? "Not connected"
            focused: root.focusedOn("wide", 0)
            onClicked: root.toggleTile(1)
            onOpened: root.openNetwork("wifi")
        }
        Tile {
            id: bluetooth
            wide: true
            width: (parent.width - parent.spacing) / 2
            height: Theme.px(62)
            order: 1
            number: "2"
            icon: "bluetooth"
            title: "Bluetooth"
            on: Bt.enabled
            subtitle: !Bt.enabled ? "Off"
                : Bt.connected.length === 0 ? "Not connected"
                : Bt.connected.map(d => d.name + (Bt.batteryOf(d) !== "" ? " · " + Bt.batteryOf(d) : "")).join(", ")
            focused: root.focusedOn("wide", 1)
            onClicked: root.toggleTile(2)
            onOpened: root.openNetwork("bluetooth")
        }
    }

    // --- Small tiles, 3 × 2. Night light grows into a full-width card in place; the rest move down.
    Item {
        id: grid
        width: parent.width
        readonly property real gap: Theme.px(8)
        readonly property real tileW: (width - 2 * gap) / 3
        readonly property real tileH: Theme.px(64)
        readonly property real cardH: nightCard.cardHeight
        readonly property var tiles: [night, dnd, game, awake, mic, airplane]
        implicitHeight: gap + (root.nightExpanded ? cardH + gap : 0) + 2 * tileH + gap

        // Position of tile i: normally a 3 × 2 grid; expanded, night light takes a row and the other five follow.
        function place(i: int): point {
            const j = root.nightExpanded ? i - 1 : i
            const top = gap + (root.nightExpanded ? cardH + gap : 0)
            return Qt.point((j % 3) * (tileW + gap), top + Math.floor(j / 3) * (tileH + gap))
        }

        component SmallTile: Tile {
            property int index
            readonly property point pos: grid.place(index)
            x: pos.x
            y: pos.y
            width: grid.tileW
            height: grid.tileH
            order: index + 2
            number: String(index + 3)
            focused: root.focusedOn(index < 3 ? "small1" : "small2", index % 3)
            onClicked: root.toggleTile(index + 3)
            Behavior on x { enabled: !Motion.reduced; NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
            Behavior on y { enabled: !Motion.reduced; NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
        }

        Tile {
            id: night
            x: 0
            y: grid.gap
            width: root.nightExpanded ? grid.width : grid.tileW
            height: root.nightExpanded ? grid.cardH : grid.tileH
            Behavior on width { enabled: !Motion.reduced; NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
            Behavior on height { enabled: !Motion.reduced; NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
            order: 2
            number: "3"
            icon: "moon"
            title: "Night light"
            on: NightLight.on
            expanded: root.nightExpanded
            tint: expanded ? "transparent" : on ? Theme.accent : Theme.white(0.08)
            focused: root.focusedOn("small1", 0) && !expanded
            // Clicking the tile toggles; the card's own switch toggles once it's open. Right-click or Enter grows
            // it and shrinks it back.
            onClicked: if (!expanded) root.toggleTile(3)
            NightLightCard {
                id: nightCard
                shown: root.nightExpanded
                focused: root.focusedOn("small1", 0) && root.nightExpanded
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: root.toggleNightCard()
            }
        }
        SmallTile { id: dnd; index: 1; icon: "bell-off"; title: "Do not disturb"; on: Modes.dnd }
        SmallTile { id: game; index: 2; icon: "gamepad"; title: "Game mode"; on: Modes.gameMode }
        SmallTile { id: awake; index: 3; icon: "coffee"; title: "Keep awake"; on: Modes.keepAwake }
        SmallTile { id: mic; index: 4; icon: Audio.micMuted ? "mic-off" : "mic"; title: "Microphone"; on: !!Audio.source && !Audio.micMuted }
        SmallTile { id: airplane; index: 5; icon: "plane"; title: "Airplane"; on: Network.airplane }
    }

    // --- Volume and brightness
    Item { width: 1; height: Theme.px(12) }
    SliderRow {
        id: volume
        width: parent.width
        icon: Audio.muted ? "volume-x" : "volume-1"
        value: Audio.muted ? 0 : Audio.volume
        fill: Theme.accent
        note: Audio.nameOf(Audio.sink)
        focused: root.focusedOn("volume", 0)
        onMoved: v => Audio.setVolume(Audio.sink, v)
        onIconClicked: Audio.toggleMute()
        onNoteClicked: Shell.controlPage = "sound"
    }
    Item { width: 1; height: Theme.px(8) }
    SliderRow {
        id: brightness
        width: parent.width
        icon: "sun"
        value: Brightness.percent / 100
        fill: Theme.secondary
        note: String(Brightness.percent)
        mono: true
        focused: root.focusedOn("brightness", 0)
        onMoved: v => Brightness.set(Math.round(v * 100))
    }

    // --- Media
    Item { width: 1; height: Theme.px(10); visible: media.visible }
    MediaCard {
        id: media
        width: parent.width
        visible: !!Media.player
        focusCol: root.at === "media" ? root.col : -1
    }

    // --- Power profile
    SectionLabel {
        text: "Power profile"
        above: Theme.px(12)
        below: Theme.px(6)
        leftPadding: Theme.px(4)
        KeyHint {
            x: parent.leftPadding + parent.contentWidth + Theme.px(6)
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: (parent.topPadding - parent.bottomPadding) / 2
            key: "P"
        }
    }
    Rectangle {
        id: profile
        width: parent.width
        height: Theme.px(36)
        radius: Theme.px(14)
        color: Theme.white(0.07)
        FocusRing { shown: root.at === "profile"; shapeRadius: parent.radius }
        Row {
            anchors.fill: parent
            anchors.margins: Theme.px(3)
            Repeater {
                model: ["Saver", "Balanced", "Performance"]
                Button {
                    id: segment
                    required property string modelData
                    required property int index
                    readonly property bool active: PowerProfiles.profile === root.profiles[index]
                    width: parent.width / 3
                    height: parent.height
                    radius: Theme.px(11)
                    hoverScale: 1
                    squish: 0.97
                    enabled: index < 2 || PowerProfiles.hasPerformanceProfile
                    base: active ? Theme.white(0.16) : "transparent"
                    onClicked: root.setProfile(index)
                    // inset 0 1px 0 white 20 % on the active segment
                    Rectangle {
                        visible: segment.active
                        x: segment.radius / 2
                        width: segment.width - segment.radius
                        height: 1
                        color: Theme.white(0.2)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: segment.modelData
                        color: segment.active ? Theme.text : Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: Theme.px(12.5)
                        font.weight: segment.active ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }

    // --- Background apps (tray): click = the app's own action, right-click / Enter = its menu.
    SectionLabel {
        visible: root.trayItems.length > 0
        text: "Background apps"
        above: Theme.px(12)
        below: Theme.px(6)
        leftPadding: Theme.px(4)
    }
    Row {
        id: tray
        visible: root.trayItems.length > 0
        x: Theme.px(2)
        width: parent.width - Theme.px(4)
        spacing: Theme.px(8)
        Repeater {
            id: trayRepeater
            model: root.trayItems
            Button {
                id: trayButton
                required property var modelData
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(34)
                height: width
                radius: Theme.px(10)
                base: trayIcon.fill
                focused: root.focusedOn("tray", index) || Shell.controlTray === modelData
                onClicked: modelData.onlyMenu ? root.openTray(index) : modelData.activate()
                TrayIcon { id: trayIcon; anchors.fill: parent; item: trayButton.modelData }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: root.openTray(trayButton.index)
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Theme.px(4)
            width: parent.width - x
            text: root.trayItems.map(i => i.tooltipTitle || i.title || i.id).join(", ") + " · Enter opens menu"
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.px(12)
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    HintBar {
        above: Theme.px(12)
        hints: [["1–8", "toggle"], ["Tab", "next row"], ["← →", "slider"], ["Esc", ""]]
    }
}
