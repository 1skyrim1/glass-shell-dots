import QtQuick
import qs.services
import qs.components
import qs.surfaces.launcher

// Left column of the notification center (18-Notifications, 19-NotifStates "Calendar: other day"):
// weekday title (30 px) and date, the month grid (Monday first, weekends faint, today in accent, a
// tertiary dot under days with events) and the events of the selected day ("Today" or e.g. "Thu 22 Oct ·
// in 2 days"). [ ] change month, T jumps back to today; with the calendar focused (Tab) H J K L / arrows
// move the day cursor and Enter shows that day.
Column {
    id: root

    property Item nc   // the NotificationCenter

    readonly property var today: nc.today
    readonly property var month: Calendar.month
    readonly property bool focusedCol: nc.focusCol === "calendar"
    function same(a: var, b: var): bool {
        return !!a && !!b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }

    // --- Title: today's weekday and date; while another month shows, that month instead.
    Item {
        width: parent.width
        height: titleCol.height + Theme.px(10)
        Column {
            id: titleCol
            x: Theme.px(4)
            y: Theme.px(2)
            Text {
                text: Qt.formatDate(root.today, "dddd")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.px(30)
                font.weight: Font.DemiBold
                font.letterSpacing: -Theme.px(0.5)
            }
            Text {
                readonly property bool otherMonth: root.month.getMonth() !== root.today.getMonth()
                                                   || root.month.getFullYear() !== root.today.getFullYear()
                text: otherMonth ? Qt.formatDate(root.month, "MMMM yyyy") : Qt.formatDate(root.today, "d MMMM yyyy")
                color: otherMonth ? Theme.accent : Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.px(13)
            }
        }
        Row {
            anchors { right: parent.right; rightMargin: Theme.px(4); top: parent.top; topMargin: Theme.px(10) }
            spacing: Theme.px(4)
            KeyHint { key: "[" }
            KeyHint { key: "]" }
        }
    }

    // --- Weekday names
    Row {
        width: parent.width
        topPadding: Theme.px(4)
        bottomPadding: Theme.px(4)
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Text {
                required property string modelData
                width: grid.cell
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.px(11)
            }
        }
    }

    // --- Month grid
    Grid {
        id: grid
        readonly property real gap: Theme.px(2)
        readonly property real cell: (root.width - 6 * gap) / 7
        // Monday-first offset of the 1st, and as many weeks as the month needs.
        readonly property int offset: (root.month.getDay() + 6) % 7
        readonly property int length: new Date(root.month.getFullYear(), root.month.getMonth() + 1, 0).getDate()
        columns: 7
        spacing: gap

        Repeater {
            model: Math.ceil((grid.offset + grid.length) / 7) * 7
            Item {
                id: cell
                required property int index
                readonly property int day: index - grid.offset + 1
                readonly property bool inMonth: day >= 1 && day <= grid.length
                readonly property var date: new Date(root.month.getFullYear(), root.month.getMonth(), day)
                readonly property bool isToday: inMonth && root.same(date, root.today)
                readonly property bool isSelected: inMonth && !isToday && root.same(date, root.nc.selected)
                readonly property bool weekend: index % 7 >= 5
                width: grid.cell
                height: Theme.px(34)

                Rectangle {
                    anchors.fill: parent
                    visible: cell.inMonth
                    radius: height / 2
                    color: cell.isToday ? Theme.accent : cell.isSelected ? Theme.alpha(Theme.accentContainer, 0.6)
                         : mouse.containsMouse ? Theme.white(0.07) : "transparent"
                    border.width: cell.isSelected ? 1 : 0
                    border.color: Theme.alpha(Theme.accent, 0.5)
                    Behavior on color { ColorAnimation { duration: Motion.micro } }
                    FocusRing {
                        shown: root.focusedCol && cell.inMonth && root.same(cell.date, root.nc.cursor)
                        shapeRadius: parent.radius
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: cell.inMonth
                    text: cell.day
                    color: cell.isToday ? Theme.textOnAccent : cell.isSelected ? Theme.textOnContainer
                         : cell.weekend ? Theme.textFaint : Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12.5)
                    font.weight: cell.isToday ? Font.Bold : Font.Normal
                }
                Rectangle {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.px(4) }
                    visible: cell.inMonth && !cell.isToday && Calendar.hasEvents(Calendar.key(cell.date))
                    width: Theme.px(4)
                    height: width
                    radius: width / 2
                    color: Theme.secondary
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    enabled: cell.inMonth
                    hoverEnabled: true
                    onClicked: root.nc.pickDay(cell.date)
                }
            }
        }
    }

    // --- Events of the selected day
    readonly property bool showsToday: same(nc.selected, today)
    readonly property var events: Calendar.eventsOn(Calendar.key(nc.selected))

    SectionLabel {
        visible: root.showsToday
        above: Theme.px(16)
        below: Theme.px(8)
        leftPadding: Theme.px(4)
        text: "Today"
    }
    Row {
        visible: !root.showsToday
        topPadding: Theme.px(16)
        bottomPadding: Theme.px(10)
        leftPadding: Theme.px(4)
        spacing: Theme.px(10)
        Text {
            id: dayTitle
            text: Qt.formatDate(root.nc.selected, "ddd d MMM")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.px(22)
            font.weight: Font.DemiBold
        }
        Text {
            anchors.baseline: dayTitle.baseline
            text: {
                const d = Math.round((new Date(root.nc.selected.getFullYear(), root.nc.selected.getMonth(), root.nc.selected.getDate())
                                      - new Date(root.today.getFullYear(), root.today.getMonth(), root.today.getDate())) / 86400000)
                return d === 0 ? "today" : d === 1 ? "tomorrow" : d === -1 ? "yesterday" : d > 0 ? `in ${d} days` : `${-d} days ago`
            }
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.px(12)
        }
    }

    Column {
        width: parent.width
        spacing: Theme.px(6)
        Repeater {
            model: root.events
            Rectangle {
                id: ev
                required property var modelData
                required property int index
                width: parent.width
                height: evText.implicitHeight + Theme.px(18)
                radius: Theme.px(12)
                color: Theme.white(0.06)
                Rectangle {
                    x: Theme.px(10)
                    y: Theme.px(9)
                    width: Theme.px(3)
                    height: parent.height - Theme.px(18)
                    radius: width / 2
                    color: [Theme.accent, Theme.secondary, Theme.roles.secondary ?? Theme.textMuted][ev.index % 3]
                }
                Column {
                    id: evText
                    x: Theme.px(23)
                    y: Theme.px(9)
                    width: parent.width - x - Theme.px(10)
                    Text {
                        width: parent.width
                        text: ev.modelData.title
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.px(12.5)
                        font.weight: Font.Medium
                    }
                    Text {
                        width: parent.width
                        text: Calendar.timeRange(ev.modelData) + (ev.modelData.location ? " · " + ev.modelData.location : "")
                        elide: Text.ElideRight
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.px(11.5)
                    }
                }
            }
        }
        Text {
            visible: root.events.length === 0
            leftPadding: Theme.px(4)
            text: "No events"
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.px(12.5)
        }
    }
    Text {
        visible: !root.showsToday
        topPadding: Theme.px(12)
        leftPadding: Theme.px(4)
        text: "T jumps back to today"
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.px(11.5)
    }
}
