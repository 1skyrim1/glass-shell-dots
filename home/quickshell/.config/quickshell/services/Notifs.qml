pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../components/apps.js" as AppIcons

// The notification daemon (DESIGN.md §3.5, §4) and its state: the list the center shows, the toast stack
// and what's held back.
// - Toasts: max 3 at once, newest in front, the rest wait. Timers (ToastStack): 5 s, 10 s with actions,
//   never for critical. An expired toast merges back into the bell and stays in the list, unread.
// - While the center is open, new notifications only go into the list.
// - Do not disturb, game mode, fullscreen (and later the lock screen) hold toasts back; when the quiet
//   time ends, one catch-up toast sums them up. Critical ones always show.
// - Opening the center reads everything (the bell's dot goes away once it closes).
Singleton {
    id: root

    property var list: []     // kept entries, newest first (the center)
    property var toasts: []   // in the stack, newest first
    property var queue: []    // waiting for a free place in the stack, oldest first
    property var held: []     // arrived during quiet time, for the catch-up toast
    readonly property int maxToasts: 3

    // Unread and not on screen as a toast: the bell's dot.
    readonly property int unread: list.filter(e => !e.read && !e.toasting).length

    // The center's cards: one per app, newest first; entries newest first.
    readonly property var groups: {
        const out = [], byKey = {}
        for (const e of list) {
            let g = byKey[e.group]
            if (!g) out.push(g = byKey[e.group] = { key: e.group, entries: [] })
            g.entries.push(e)
        }
        return out
    }
    readonly property var groupKeys: groups.map(g => g.key)
    function groupOf(key: string): var { return groups.find(g => g.key === key) ?? null }

    // --- Quiet time
    readonly property bool centerOpen: Shell.panel === "notifications"
    readonly property bool fullscreen: Hyprland.focusedWorkspace?.hasFullscreen ?? false
    // A recording holds them back too, so they never end up in the clip (§4).
    readonly property string quietReason: Shell.locked ? "away" : Modes.gameMode ? "gaming"
        : Recorder.recording ? "recording" : Modes.dnd ? "dnd" : fullscreen ? "fullscreen" : ""
    readonly property bool quiet: quietReason !== ""
    property real quietSince: 0
    property string quietKind: ""   // the reason the summary names (game mode wins over the others)
    onQuietReasonChanged: {
        // Later: bindings that depend on quietReason (quiet) may not have caught up inside this handler.
        if (quietReason === "") return Qt.callLater(catchUp)
        if (quietSince === 0) quietSince = Date.now()
        if (quietKind !== "gaming") quietKind = quietReason
    }
    readonly property var quietTitles: ({
        gaming: "While you were gaming",
        dnd: "While do not disturb was on",
        fullscreen: "While you were in fullscreen",
        recording: "While you were recording",
        away: "While you were away"
    })

    function catchUp() {
        const h = held.filter(e => list.includes(e) && !e.read)
        const since = quietSince, kind = quietKind
        held = []
        quietSince = 0
        quietKind = ""
        if (h.length === 0) return
        const apps = [...new Set(h.map(e => e.app))]
        const names = apps.length > 1 ? apps.slice(0, -1).join(", ") + " and " + apps[apps.length - 1] : apps[0]
        const span = duration(Date.now() - since)
        make({
            app: quietTitles[kind] ?? quietTitles.dnd,
            body: `${h.length} notification${h.length > 1 ? "s" : ""} from ${names}`,
            icon: "bell",
            colors: { fill: Theme.accentContainer, stroke: Theme.textOnContainer },
            toastOnly: true,
            meta: () => span,
            run: () => Shell.open("notifications"),
            actions: [
                { text: "Show", run: () => Shell.open("notifications") },
                { text: "Clear", run: () => h.forEach(e => root.dismiss(e)) }
            ]
        })
    }

    // --- Arrivals
    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        inlineReplySupported: true
        extraHints: ["value"]   // progress
        onNotification: n => root.receive(n, true)
    }
    // After a reload the server still has its notifications; list them again without toasts.
    Component.onCompleted: {
        const old = server.trackedNotifications.values
        for (let i = old.length - 1; i >= 0; i--) receive(old[i], false)
    }

    Component { id: entryType; NotifEntry {} }
    property int lastUid: 0

    function receive(n: Notification, toast: bool) {
        n.tracked = true
        const e = entryType.createObject(root, { n: n, read: !toast, uid: ++lastUid })
        n.closed.connect(() => root.closed(e))
        if (toast) add(e)
        else list = list.concat([e])
    }
    // A notification made by the shell (calendar reminder, catch-up).
    function make(props: var): var {
        const e = entryType.createObject(root, Object.assign({ uid: ++lastUid }, props))
        add(e)
        return e
    }
    function add(e: var) {
        if (!e.toastOnly) list = [e].concat(list)
        if (centerOpen) {
            e.read = true
            if (e.toastOnly) drop(e)
        } else if (quietReason !== "" && !e.critical) {
            if (e.toastOnly) drop(e)
            else held = held.concat([e])
        } else {
            showToast(e)
        }
    }

    // --- Toasts. The stack (ToastStack) animates each one in and out; leave() starts the merge back into
    // the bell and toastDone() is called once it's gone.
    function showToast(e: var) {
        if (toasts.length >= maxToasts) {
            queue = queue.concat([e])
            return
        }
        e.toasting = true
        e.leaving = false
        toasts = [e].concat(toasts)
    }
    function leave(e: var) { if (e.toasting) e.leaving = true }
    function toastDone(e: var) {
        toasts = toasts.filter(t => t !== e)
        e.toasting = false
        e.leaving = false
        if (e.toastOnly) drop(e)
        if (queue.length > 0 && toasts.length < maxToasts) {
            const next = queue[0]
            queue = queue.slice(1)
            showToast(next)
        }
    }
    // Opening the center pulls the toasts back in (their notifications are in the list).
    onCenterOpenChanged: {
        if (centerOpen) {
            toasts.forEach(leave)
            queue.forEach(e => { if (e.toastOnly) drop(e) })
            queue = []
        } else {
            list.forEach(e => e.read = true)
        }
    }

    // --- Actions
    // Click / Enter: the app's default action (it focuses the app and, unless resident, closes the
    // notification), else bring the app's window to the front.
    function open(e: var) {
        e.read = true
        if (e.defaultAction) {
            e.defaultAction.invoke()
        } else if (e.run) {
            e.run()
            if (e.toastOnly || !e.n) dismiss(e)
        } else {
            focusApp(e)
            dismiss(e)
        }
        leave(e)
    }
    function act(e: var, a: var) {
        e.read = true
        a.run()
        if (!e.n) dismiss(e)   // the shell's own: done once acted on (app ones close themselves)
        leave(e)
    }
    function focusApp(e: var) {
        const want = [e.desktopEntry, e.app].filter(s => s).map(s => s.toLowerCase())
        const w = Hyprland.toplevels.values.find(t => {
            const cls = AppIcons.classOf(t).toLowerCase()
            return cls !== "" && want.some(s => cls === s || cls.endsWith("." + s) || s.endsWith("." + cls))
        })
        if (w) Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${w.address}" })`)
    }
    function dismiss(e: var) {
        if (e.n) e.n.dismiss()   // → closed()
        else drop(e)
    }
    function dismissGroup(key: string) { (groupOf(key)?.entries ?? []).forEach(dismiss) }
    function markGroupRead(key: string) { (groupOf(key)?.entries ?? []).forEach(e => e.read = true) }
    function clearAll() { list.slice().forEach(dismiss) }

    // Inline reply: send, show "Sent ✓" for a moment, then collapse the card. Sending may close the
    // notification right away, so the entry lets go of it first and finishes on its own timer.
    function reply(e: var, text: string) {
        const n = e.n
        if (!n || text.trim() === "") return
        e.read = true
        e.sent = true
        e.draft = ""
        e.freeze()
        let closed = false
        n.closed.connect(() => closed = true)
        n.sendInlineReply(text)
        later(Motion.replySent, () => {
            if (!closed) n.dismiss()
            root.drop(e)
        })
    }

    // The app (or we) closed it.
    function closed(e: var) {
        if (e.sent) return   // reply() finishes it
        e.freeze()
        drop(e)
    }
    // Gone from everywhere; a toast still showing merges back first.
    function drop(e: var) {
        list = list.filter(x => x !== e)
        queue = queue.filter(x => x !== e)
        held = held.filter(x => x !== e)
        if (e.toasting) {
            e.toastOnly = true   // toastDone() drops it again, then it's really gone
            leave(e)
            return
        }
        e.destroy(1000)   // after the delegates showing it are gone
    }

    // --- Time labels, refreshed every 30 s ("now", "2 min", "1 h", "yesterday", "Mon 19 Oct")
    property real now: Date.now()
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }
    function ago(t: real): string {
        const s = Math.max(0, (now - t) / 1000)
        if (s < 60) return "now"
        if (s < 3600) return Math.floor(s / 60) + " min"
        const d = new Date(t), today = new Date(now)
        if (s < 6 * 3600 || d.toDateString() === today.toDateString()) return Math.floor(s / 3600) + " h"
        const y = new Date(now - 86400000)
        if (d.toDateString() === y.toDateString()) return "yesterday"
        return Qt.formatDate(d, "ddd d MMM")
    }
    function duration(ms: real): string {
        const m = Math.max(1, Math.round(ms / 60000))
        return m < 60 ? m + " min" : Math.floor(m / 60) + " h" + (m % 60 ? " " + (m % 60) + " min" : "")
    }
    function metaOf(e: var): string { return e.meta ? e.meta() : ago(e.time) }

    // Runs fn after ms (reply "Sent ✓", reminder snooze).
    Component {
        id: delay
        Timer {
            property var fn
            running: true
            onTriggered: { fn(); destroy() }
        }
    }
    function later(ms: int, fn: var) { delay.createObject(root, { interval: ms, fn: fn }) }
}
