pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Calendar events from khal (local calendars in ~/.config/khal/config; DESIGN.md §3.5): the month the
// notification center shows (event dots, day lists) and the next two days for reminders 10 min before an
// event. khal prints one JSON array per day of the range, recurring events already expanded.
// Refreshed when the center opens, when its month changes, every 5 min and on `qs ipc call calendar refresh`.
Singleton {
    id: root

    // "YYYY-MM-DD" → [{ title, start, end, startTime, endTime, allDay, location, uid }], sorted by time.
    property var days: ({})
    property var soon: ({})
    // First day of the range `days` covers (the center's month, a week either side).
    property var month: new Date(new Date().getFullYear(), new Date().getMonth(), 1)

    readonly property int reminderLead: 10   // minutes before an event
    readonly property int snoozeMinutes: 5

    function key(d: var): string { return Qt.formatDate(d, "yyyy-MM-dd") }
    function eventsOn(k: string): var { return days[k] ?? soon[k] ?? [] }
    function hasEvents(k: string): bool { return eventsOn(k).length > 0 }

    function showMonth(d: var) {
        month = new Date(d.getFullYear(), d.getMonth(), 1)
        loadMonth()
    }
    function refresh() {
        loadMonth()
        loadSoon()
    }

    readonly property var fields: ["title", "start-date", "start-time", "end-date", "end-time", "all-day", "location", "uid"]
    function command(from: var, to: var): var {
        const args = ["khal", "list"]
        for (const f of fields) args.push("--json", f)
        return args.concat([key(from), key(to)])
    }
    // One line per day from `from` on.
    function parse(text: string, from: var): var {
        const out = {}
        const lines = text.split("\n").filter(l => l.trim().startsWith("["))
        lines.forEach((line, i) => {
            const d = new Date(from.getFullYear(), from.getMonth(), from.getDate() + i)
            let evs = []
            try { evs = JSON.parse(line) } catch (e) { return }
            if (evs.length === 0) return
            out[key(d)] = evs.map(ev => ({
                title: ev.title,
                allDay: ev["all-day"] === "True",
                start: ev["start-time"] ? new Date(`${ev["start-date"]}T${ev["start-time"]}`) : new Date(`${ev["start-date"]}T00:00`),
                startTime: ev["start-time"],
                endTime: ev["end-time"],
                location: ev.location ?? "",
                uid: ev.uid
            })).sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start))
        })
        return out
    }

    function loadMonth() {
        const from = new Date(month.getFullYear(), month.getMonth(), 1 - 7)
        const to = new Date(month.getFullYear(), month.getMonth() + 1, 7)
        monthProc.from = from
        monthProc.command = command(from, to)
        monthProc.running = true
    }
    function loadSoon() {
        const now = new Date()
        const from = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        soonProc.from = from
        soonProc.command = command(from, new Date(from.getFullYear(), from.getMonth(), from.getDate() + 1))
        soonProc.running = true
    }

    Process {
        id: monthProc
        property var from
        stdout: StdioCollector { onStreamFinished: root.days = root.parse(text, monthProc.from) }
    }
    Process {
        id: soonProc
        property var from
        stdout: StdioCollector {
            onStreamFinished: {
                root.soon = root.parse(text, soonProc.from)
                root.checkReminders()
            }
        }
    }

    Component.onCompleted: refresh()
    Timer {
        interval: 5 * 60000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // --- Reminders: timed events starting within the next 10 min, once each (uid + start).
    property var reminded: ({})
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.checkReminders()
    }
    function checkReminders() {
        const now = Date.now()
        for (const k in soon) {
            for (const ev of soon[k]) {
                const id = ev.uid + ev.start.getTime()
                const left = ev.start.getTime() - now
                if (ev.allDay || reminded[id] || left <= 0 || left > reminderLead * 60000) continue
                reminded[id] = true
                remind(ev)
            }
        }
    }
    function timeRange(ev: var): string {
        if (ev.allDay) return "all day"
        return ev.endTime ? `${ev.startTime} – ${ev.endTime}` : ev.startTime
    }
    function remind(ev: var) {
        const start = ev.start.getTime()
        Notifs.make({
            app: "Calendar",
            body: `<b>${ev.title.replace(/&/g, "&amp;").replace(/</g, "&lt;")}</b> · ${timeRange(ev)}`,
            icon: "calendar",
            meta: () => {
                const m = Math.round((start - Notifs.now) / 60000)
                return m > 0 ? `in ${m} min` : "now"
            },
            actions: [
                { text: `Snooze ${snoozeMinutes} min`, run: () => Notifs.later(snoozeMinutes * 60000, () => root.remind(ev)) },
                { text: "Dismiss", run: () => {} }
            ]
        })
    }
}
