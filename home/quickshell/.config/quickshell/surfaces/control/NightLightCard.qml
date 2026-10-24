import QtQuick
import qs.services
import qs.components

// Night light, expanded (17-ControlPages): the tile grown in place into a warm card. Switch, the
// warm → cool temperature slider with a knob, and the schedule with the current temperature.
// Fills its tile; fades in while the tile grows. `focused` = ← → move the temperature.
Item {
    id: root

    property bool shown: false
    property bool focused: false
    readonly property real cardHeight: Theme.px(98)
    readonly property real range: NightLight.maxK - NightLight.minK

    function nudge(dir: int) { NightLight.setTemperature(NightLight.temperature + dir * 100) }

    anchors.fill: parent
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }

    // The card sits on the tile: warning 14 % fill + 35 % border (in place of the tile's own fill).
    Rectangle {
        anchors.fill: parent
        radius: Theme.px(18)
        color: Theme.alpha(Theme.warning, 0.14)
        border.width: 1
        border.color: Theme.alpha(Theme.warning, 0.35)
        FocusRing { shown: root.focused; shapeRadius: parent.radius }
    }

    Column {
        x: Theme.px(14)
        y: Theme.px(12)
        width: parent.width - Theme.px(28)
        spacing: Theme.px(12)

        Row {
            width: parent.width
            spacing: Theme.px(10)
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "moon"; size: Theme.px(16); color: Theme.textOnWarning }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.px(16) - sw.width - 2 * parent.spacing
                text: "Night light"
                color: Theme.textOnWarning
                font.family: Theme.font
                font.pixelSize: Theme.px(13)
                font.weight: Font.DemiBold
            }
            Switch {
                id: sw
                anchors.verticalCenter: parent.verticalCenter
                small: true
                checked: NightLight.on
                onColor: Theme.warning
                knobColor: Qt.darker(Theme.warning, 4.5)
                onToggled: NightLight.toggle()
            }
        }

        Row {
            width: parent.width
            spacing: Theme.px(10)
            component End: Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textOnWarning
                font.family: Theme.font
                font.pixelSize: Theme.px(12)
            }
            End { id: warm; text: "warm" }
            Slider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - warm.width - cool.width - 2 * parent.spacing
                knob: true
                showFill: false
                trackFrom: Theme.nightWarm
                trackTo: Theme.nightCool
                step: 100 / root.range
                value: (NightLight.temperature - NightLight.minK) / root.range
                onMoved: v => NightLight.setTemperature(NightLight.minK + v * root.range)
            }
            End { id: cool; text: "cool" }
        }

        Text {
            topPadding: -Theme.px(2)
            text: NightLight.scheduleText + " · " + NightLight.temperature + " K"
            color: Theme.textOnNight
            font.family: Theme.font
            font.pixelSize: Theme.px(12)
        }
    }
}
