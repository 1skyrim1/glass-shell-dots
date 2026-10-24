import QtQuick
import Quickshell.Bluetooth
import qs.services
import qs.components

// Status pill (DESIGN.md §2.4): layout badge, Wi-Fi, Bluetooth, microphone in use, volume, battery.
// Game mode / keep awake add accent circles at the start. Low battery stretches it leftwards in amber for
// 5 s (09-Bar "Low battery"). Click = Control Center (stays lit while open), scroll = volume; left-click on the badge =
// next layout, right-click = layout menu (LayoutMenu; the badge is lit while it's open).
// Icons whose state isn't readable at a glance have tooltips (TipArea).
Pill {
    id: root

    readonly property bool warn: Battery.warning
    readonly property bool modes: Modes.gameMode || Modes.keepAwake

    // Wi-Fi signal: 0 = off / not connected, else 1–4 arcs.
    readonly property int wifiBars: Network.bars
    readonly property bool bluetooth: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property Item badge: badge   // the layout menu opens under it

    // Tooltip texts (10-Popovers "Tooltips").
    function duration(min: int): string {
        return min >= 60 ? Math.floor(min / 60) + " h " + (min % 60) + " min" : min + " min"
    }
    readonly property string wifiTip: Network.tip
    readonly property string bluetoothTip: {
        const names = Bluetooth.devices.values.filter(d => d.connected).map(d => d.name)
        return names.length > 0 ? names.join(", ") : "Bluetooth · nothing connected"
    }
    readonly property string volumeTip: (Audio.sink?.description || Audio.sink?.nickname || "Speakers")
        + " · " + (Audio.muted ? "muted" : "volume " + Audio.percent + " %")
    readonly property string batteryTip: "Battery " + Battery.percent + " % · "
        + (Battery.charging ? "charging"
           : Battery.pluggedIn ? "plugged in"
           : Battery.minutesLeft > 0 ? duration(Battery.minutesLeft) + " left" : "on battery")

    lit: Shell.isOpen("control")
    tone: warn ? "warning" : ""
    implicitWidth: warn ? warnRow.implicitWidth + 2 * Theme.px(13)
                        : normalRow.x + normalRow.implicitWidth + Theme.px(12)

    onClicked: Shell.toggle("control", "status")
    onScrolled: step => step < 0 ? Audio.up() : Audio.down()

    component StatusIcon: Icon {
        anchors.verticalCenter: parent?.verticalCenter
        color: root.warn ? Theme.textOnWarning : Theme.text
    }

    // Wi-Fi with the missing arcs faint, like a signal meter.
    component WifiIcon: Item {
        anchors.verticalCenter: parent?.verticalCenter
        implicitWidth: full.implicitWidth
        implicitHeight: full.implicitHeight
        StatusIcon {
            id: full
            name: root.wifiBars === 0 ? "wifi-off" : "wifi"
            opacity: root.wifiBars === 0 || root.wifiBars === 4 ? 1 : 0.3
        }
        StatusIcon {
            visible: root.wifiBars > 0 && root.wifiBars < 4
            name: "wifi-" + root.wifiBars
        }
        TipArea { text: root.wifiTip; icon: root.wifiBars > 0 ? "wifi" : "wifi-off" }
    }

    component VolumeIcon: StatusIcon {
        name: Audio.muted ? "volume-x" : "volume-1"
        TipArea { text: root.volumeTip }
    }

    // Battery outline (viewBox 28 × 24 in a 20 px slot) with the charge level as a bar inside.
    component BatteryIcon: Item {
        id: battery
        property color fill: icon.color
        property real level: Battery.percent / 100
        anchors.verticalCenter: parent?.verticalCenter
        implicitWidth: Theme.px(20)
        implicitHeight: icon.implicitHeight
        StatusIcon {
            id: icon
            x: (parent.width - width) / 2
            name: "battery"
        }
        Rectangle {
            readonly property real unit: icon.size / 24
            x: icon.x + 5 * unit
            y: icon.y + 9 * unit
            width: Math.max(3, 14 * battery.level) * unit   // never thinner than the design's 12 % sliver
            height: 6 * unit
            radius: unit
            color: battery.fill
            Behavior on width { NumberAnimation { duration: Motion.small } }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 1
        clip: true

        // --- Normal: [modes] DE wifi bt mic vol battery%
        Row {
            id: normalRow
            x: Theme.px(root.modes ? 6 : 9) - 1
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(10)
            opacity: root.warn ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Motion.small } }

            Row {
                visible: root.modes
                spacing: Theme.px(4)
                Repeater {
                    model: [{ on: Modes.gameMode, icon: "gamepad", tip: "Game mode on" },
                            { on: Modes.keepAwake, icon: "coffee", tip: "Keep awake on" }]
                    Rectangle {
                        required property var modelData
                        visible: modelData.on
                        width: Theme.px(26)
                        height: width
                        radius: width / 2
                        color: Theme.alpha(Theme.accent, 0.22)
                        Icon {
                            anchors.centerIn: parent
                            name: parent.modelData.icon
                            size: Theme.px(14)
                            color: Theme.accent
                        }
                        TipArea { text: parent.modelData.tip }
                    }
                }
            }

            // Layout badge: Geist Mono 11 on a white 8 % chip.
            // Lit (accent 30 %) while its layout menu is open.
            Rectangle {
                id: badge
                readonly property bool lit: Shell.popover === "layout"
                visible: Keyboard.short !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: badgeText.implicitWidth + Theme.px(14)
                height: badgeText.implicitHeight + Theme.px(6)
                radius: Theme.px(8)
                color: lit ? Theme.alpha(Theme.accent, 0.3) : Theme.white(badgeMouse.containsMouse ? 0.14 : 0.08)
                Behavior on color { ColorAnimation { duration: Motion.micro } }
                Behavior on width { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: Keyboard.short
                    color: badge.lit ? Theme.textOnContainer : Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.px(11)
                }
                MouseArea {
                    id: badgeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: e => e.button === Qt.RightButton ? Shell.togglePopover("layout", root.screenName) : Keyboard.next()
                }
            }

            WifiIcon {}
            StatusIcon { visible: root.bluetooth; name: "bluetooth"; TipArea { text: root.bluetoothTip } }
            StatusIcon { visible: Audio.micInUse; name: "mic"; color: Theme.error; TipArea { text: "Microphone in use" } }
            VolumeIcon {}

            Item {
                visible: Battery.present
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: batteryRow.implicitWidth
                implicitHeight: batteryRow.implicitHeight
                Row {
                    id: batteryRow
                    spacing: Theme.px(5)
                    BatteryIcon { fill: Battery.charging ? Theme.good : Theme.text }
                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Battery.percent + "%"
                        font.pixelSize: Theme.px(12)
                    }
                }
                TipArea { text: root.batteryTip }
            }
        }

        // --- Low battery: amber battery, "12 %", time left, then just Wi-Fi and volume.
        Row {
            id: warnRow
            x: Theme.px(13) - 1
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(10)
            opacity: root.warn ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Motion.small } }

            BatteryIcon { fill: Theme.warning }
            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.percent + " %"
                font.weight: Font.DemiBold
                color: Theme.textOnWarning
            }
            BarText {
                anchors.verticalCenter: parent.verticalCenter
                readonly property int m: Battery.minutesLeft
                text: (m <= 0 ? "" : "about " + (m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min") + " left · ")
                      + "plug in"
                font.pixelSize: Theme.px(12.5)
                color: Theme.textOnWarning
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Theme.px(16)
                color: Theme.alpha(Theme.textOnWarning, 0.3)
            }
            WifiIcon {}
            VolumeIcon {}
        }
    }
}
