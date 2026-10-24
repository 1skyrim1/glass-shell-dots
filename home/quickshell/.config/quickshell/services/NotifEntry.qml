import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// One notification in the list and its toast (Notifs). Either wraps a D-Bus `Notification` (n) and follows
// it live, so an app replacing it (progress) updates the same card in place, or is made by the shell
// itself (calendar reminder, catch-up summary) with the fields set directly and `n` null.
// Before `n` goes away (closed, replied) freeze() copies the current values, so the card can still
// animate out with its content.
QtObject {
    id: root

    property Notification n: null
    property real time: Date.now()

    property string app: n ? (n.appName || n.desktopEntry) : ""
    property string desktopEntry: n?.desktopEntry ?? ""
    property string summary: n?.summary ?? ""
    property string body: n?.body ?? ""
    property string image: n?.image ?? ""
    property bool critical: n ? n.urgency === NotificationUrgency.Critical : false
    property bool toastOnly: n?.transient ?? false   // "transient" hint: toast, but not kept in the list
    // Progress hint (0–100), −1 = none.
    property int progress: n?.hints?.value ?? -1
    property bool replyable: n?.hasInlineReply ?? false
    property string placeholder: n?.inlineReplyPlaceholder || (summary ? "Reply to " + summary : "Reply")
    // Buttons: [{ text, run }]. The app's "default" action isn't a button; it's what click / Enter does.
    property var actions: {
        if (!n) return []
        const out = []
        for (let i = 0; i < n.actions.length; i++) {
            const a = n.actions[i]
            if (a.identifier !== "default") out.push({ text: a.text, run: () => a.invoke() })
        }
        return out
    }
    property var defaultAction: {
        if (!n) return null
        for (let i = 0; i < n.actions.length; i++)
            if (n.actions[i].identifier === "default") return n.actions[i]
        return null
    }

    // Shell-made entries: Lucide icon + tile colours, what click / Enter does, and the header's right side
    // ("in 10 min", "1 h 12 min") instead of the age.
    property string icon: ""
    property var colors: null
    property var run: null
    property var meta: null   // function returning the text, so it stays current

    // The list groups plain messages by app (a chat's messages); anything with progress, an image, buttons
    // or critical urgency gets its own card, so those stay visible.
    property int uid: 0
    readonly property string group: progress >= 0 || image !== "" || actions.length > 0 || critical
        ? "#" + uid : (desktopEntry || app).toLowerCase()

    property bool read: false
    property bool toasting: false   // in the toast stack (incl. while merging back)
    property bool leaving: false    // its toast is merging back into the bell
    property string draft: ""       // inline reply typed so far (Esc keeps it)
    property bool sent: false       // reply sent: "Sent ✓" for a moment, then the card collapses

    function freeze() {
        app = app; desktopEntry = desktopEntry; summary = summary; body = body; image = image
        critical = critical; toastOnly = toastOnly; progress = progress; replyable = false
        placeholder = placeholder; actions = []; defaultAction = null
        n = null
    }
}
