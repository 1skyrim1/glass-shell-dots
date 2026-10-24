import QtQuick
import Quickshell
import qs.services
import qs.components

// Notification center (DESIGN.md §3.5, 18-Notifications): Super+N, the clock or the bell. An 800 px panel
// under the clock: calendar on the left, notifications on the right. It drips out of the clock and springs
// open (04-MotionOverlays "Notification center", 420 ms); the two columns fade up once the shape is 60 %
// done, the list a little after the calendar. Closing pulls it back into the clock (240 ms).
// Keys: Tab switches calendar ↔ list. List: J/K or ↑/↓ move, Enter open (closes the center), R reply,
// D dismiss, Space expands a group, a button's letter presses it. Calendar: H J K L or arrows move the
// day, Enter shows that day. Anywhere: [ ] month, T today, Shift+D clear all, Esc collapses / closes.
Item {
    id: root

    required property Item clock
    property string screenName
    anchors.fill: parent

    readonly property bool shown: Shell.panel === "notifications" && (Shell.panelScreen === "" || Shell.panelScreen === screenName)
    readonly property alias body: panel.body
    readonly property alias dimLevel: panel.dimLevel
    readonly property bool active: panel.visible

    // --- State
    property string focusCol: "list"   // "list" | "calendar"
    property int sel: 0                // selected card
    property string expanded: ""       // expanded group
    property string replyKey: ""       // group whose reply field has the keyboard
    property var cursor: today        // calendar keyboard cursor
    property var selected: today      // the day whose events show

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    readonly property var today: new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate())

    readonly property var keys: Notifs.groupKeys
    readonly property string selKey: keys[Math.min(sel, keys.length - 1)] ?? ""
    readonly property var selGroup: Notifs.groupOf(selKey)
    onKeysChanged: {
        sel = Math.max(0, Math.min(sel, keys.length - 1))
        if (keys.length === 0 && focusCol === "list") focusCol = "calendar"
        if (expanded !== "" && !keys.includes(expanded)) expanded = ""
        if (replyKey !== "" && !keys.includes(replyKey)) stopReply()
    }

    onShownChanged: if (shown) {
        sel = 0
        expanded = ""
        replyKey = ""
        focusCol = keys.length > 0 ? "list" : "calendar"
        cursor = today
        selected = today
        Calendar.showMonth(today)
        Calendar.loadSoon()
    }

    // --- Calendar
    function pickDay(d: var) {
        cursor = d
        selected = d
        focusCol = "calendar"
    }
    function moveCursor(days: int) {
        cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + days)
        if (cursor.getMonth() !== Calendar.month.getMonth() || cursor.getFullYear() !== Calendar.month.getFullYear())
            Calendar.showMonth(cursor)
    }
    function changeMonth(step: int) {
        const m = new Date(Calendar.month.getFullYear(), Calendar.month.getMonth() + step, 1)
        Calendar.showMonth(m)
        const last = new Date(m.getFullYear(), m.getMonth() + 1, 0).getDate()
        cursor = new Date(m.getFullYear(), m.getMonth(), Math.min(cursor.getDate(), last))
    }
    function goToday() {
        cursor = today
        selected = today
        Calendar.showMonth(today)
    }

    // --- List
    function openSelected() {
        const g = selGroup
        if (!g) return
        Shell.close("notifications")
        Notifs.open(g.entries[0])
    }
    function toggleExpand(key: string) { expanded = expanded === key ? "" : key }
    function startReply(key: string) {
        const i = keys.indexOf(key)
        if (i < 0 || !Notifs.groupOf(key).entries[0].replyable) return
        sel = i
        focusCol = "list"
        replyKey = key
    }
    function stopReply() {
        replyKey = ""
        panel.forceActiveFocus()
    }
    function moveSel(step: int) {
        if (keys.length === 0) return
        sel = Math.max(0, Math.min(keys.length - 1, sel + step))
        list.reveal(sel)
    }

    function key(e: var): bool {
        const k = e.key, shift = e.modifiers & Qt.ShiftModifier
        if (k === Qt.Key_Escape) {
            if (expanded !== "") expanded = ""
            else Shell.close("notifications")
            return true
        }
        if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
            focusCol = focusCol === "list" || keys.length === 0 ? "calendar" : "list"
            return true
        }
        if (k === Qt.Key_BracketLeft || k === Qt.Key_BracketRight) {
            changeMonth(k === Qt.Key_BracketLeft ? -1 : 1)
            return true
        }
        if (k === Qt.Key_T) {
            goToday()
            return true
        }
        if (k === Qt.Key_D && shift) {
            Notifs.clearAll()
            return true
        }
        if (focusCol === "calendar") {
            const step = { [Qt.Key_H]: -1, [Qt.Key_Left]: -1, [Qt.Key_L]: 1, [Qt.Key_Right]: 1,
                           [Qt.Key_K]: -7, [Qt.Key_Up]: -7, [Qt.Key_J]: 7, [Qt.Key_Down]: 7 }[k]
            if (step !== undefined) moveCursor(step)
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) selected = cursor
            else return false
            return true
        }
        if (k === Qt.Key_J || k === Qt.Key_Down) moveSel(1)
        else if (k === Qt.Key_K || k === Qt.Key_Up) moveSel(-1)
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) openSelected()
        else if (k === Qt.Key_R) startReply(selKey)
        else if (k === Qt.Key_D) Notifs.dismissGroup(selKey)
        else if (k === Qt.Key_Space) { if ((selGroup?.entries.length ?? 0) > 1) toggleExpand(selKey) }
        else if (k >= Qt.Key_A && k <= Qt.Key_Z) {
            // A button's letter (ActionRow.keyLetters): the selected card's, else the first card that has it.
            const letter = String.fromCharCode(k)
            const order = [sel].concat(keys.map((_, i) => i).filter(i => i !== sel))
            const row = order.map(i => list.cardAt(i)?.actionRow).find(r => r && r.letters.includes(letter))
            if (!row) return false
            row.triggered(row.actions[row.letters.indexOf(letter)])
        }
        else return false
        return true
    }

    Panel {
        id: panel
        pill: root.clock
        shown: root.shown
        openMs: Motion.notifIn
        closeMs: Motion.notifOut
        finalWidth: Theme.px(800)
        finalY: Theme.px(58)
        finalRadius: Theme.px(26)
        padding: Theme.px(16)

        Keys.onPressed: e => { if (root.key(e)) e.accepted = true }

        Row {
            id: columns
            width: parent.width
            spacing: Theme.px(16)
            // The list fades up a little after the calendar.
            readonly property real later: Math.max(0, Math.min(1, Motion.frames(panel.p, [[0.7, 0], [1, 1]])))

            CalendarColumn {
                id: calendar
                nc: root
                width: Theme.px(330)
            }
            Rectangle {
                width: 1
                height: Math.max(calendar.height, list.height)
                color: Theme.white(0.10)
            }
            NotifColumn {
                id: list
                nc: root
                width: parent.width - calendar.width - 1 - 2 * parent.spacing
                maxListHeight: root.height - panel.finalY - 2 * panel.padding - Theme.px(12) - Theme.px(80)
                opacity: panel.closing ? 1 : columns.later
                transform: Translate { y: panel.closing ? 0 : Theme.px(6) * (1 - columns.later) }
            }
        }
    }
}
