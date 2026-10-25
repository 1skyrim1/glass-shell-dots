import QtQuick
import qs.services
import qs.components

// What the greeter and the lock screen share (26-Login, 27-LoginUsers, 28-Lock, 29-LockPower, 30-SessionStates):
// the big clock + date at top 118, avatar 104 + name + password pill at top 486, the chips at the bottom
// (user chip bottom-left, greeter only and only with more than one user; battery + power bottom-right),
// the user switcher (Alt+U) and power options (Alt+P) growing up out of their chips, the Caps Lock chip and
// the wait line under the pill. The owner draws the backdrop and does the authentication: it gets
// submitted(password) and sets `status`.
//
// Motion (06-MotionSession), driven by the owner:
//   enterT 0 → 1  lock: the clock grows out of the clock pill, date, avatar + field and chips rise in
//   leaveT 0 → 1  unlock / log in: avatar + field go (unlock: up, log in: sink), chips drop, the clock
//                 shrinks into the clock pill
Item {
    id: root

    property string mode: "lock"        // "lock" | "greeter"
    property string displayName: ""
    property string face: ""            // picture path
    property string faceFallback: ""    // (the wallpaper)
    property bool passwordless: false   // Guest: "No password · press Enter"
    property var users: []              // greeter: [{ name, display, face, sub, guest }]
    property int userIndex: 0
    property int lastUsed: 0
    property string status: ""          // PasswordPill states
    property string note: ""            // red line under the pill (the wait)
    property bool active: true          // takes keys (one screen of several)

    property real enterT: 1
    property real leaveT: 0
    property string leaveKind: "unlock"  // "unlock" | "login"

    signal submitted(string password)
    signal powerAction(string kind)
    signal userChosen(int index)
    signal escaped()

    readonly property bool usersShown: mode === "greeter" && users.length > 1
    readonly property bool popoverOpen: powerMenu.shown || userMenu.shown

    function focusField() { input.forceActiveFocus() }
    Component.onCompleted: {
        if (active) focusField()
        Keyboard.refreshCaps()
    }
    onActiveChanged: if (active) focusField()
    onStatusChanged: {
        if (status === "wrong") input.text = ""
        if (status === "") focusField()
    }
    onUserIndexChanged: input.text = ""

    // --- Motion helpers: eased 0 → 1 between a and b.
    function seg(t: real, a: real, b: real): real {
        const u = Math.max(0, Math.min(1, (t - a) / (b - a)))
        return u * u * (3 - 2 * u)
    }
    readonly property real inCentre: seg(enterT, 0.33, 1)
    readonly property real outCentre: seg(leaveT, 0, 0.61)
    readonly property real inChips: seg(enterT, 0.33, 0.83)
    readonly property real outChips: seg(leaveT, 0, 0.5)

    // --- Clock + date
    SessionClock {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.px(118)
        lockIcon: root.mode === "lock"
        fly: root.seg(root.enterT, 0, 0.83) * (1 - root.seg(root.leaveT, 0, 1))
        // From the big clock's centre to the clock pill's (10 + 38 / 2).
        flyDy: Theme.px(29) - (y + clock.clock.height / 2)
        timeOpacity: root.seg(root.enterT, 0, 0.17) * (1 - root.seg(root.leaveT, 0.8, 1))
        dateOpacity: root.seg(root.enterT, 0.33, 0.83) * (1 - root.seg(root.leaveT, 0, 0.37))
    }

    // --- Avatar, name, password pill
    Column {
        id: centre
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.px(486)
        opacity: root.inCentre * (1 - root.outCentre) * (powerMenu.shown ? 0.55 : 1)
        Behavior on opacity { enabled: root.leaveT === 0 && root.enterT === 1; NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
        transform: [
            Scale {
                origin.x: centre.width / 2
                origin.y: centre.height / 2
                xScale: 1 - (root.leaveKind === "login" ? 0.03 : 0.04) * root.outCentre
                yScale: xScale
            },
            Translate { y: Theme.px(30) * (1 - root.inCentre) + Theme.px(root.leaveKind === "login" ? 24 : -10) * root.outCentre }
        ]

        Avatar {
            anchors.horizontalCenter: parent.horizontalCenter
            ring: true
            source: root.face
            fallback: root.faceFallback
            letter: root.displayName.charAt(0)
        }
        Item { width: 1; height: Theme.px(16) }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.displayName
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.px(21)
            font.weight: Font.DemiBold
        }
        Item { width: 1; height: Theme.px(24) }
        PasswordPill {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            count: input.text.length
            status: root.status
            caret: input.activeFocus
            placeholder: root.passwordless ? "No password · press Enter" : "Enter password"
            onGoClicked: root.submit()
            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: Theme.px(50)
                onClicked: root.focusField()
            }
        }
        Item { width: 1; height: Theme.px(14) }
        // The wait after too many tries (red), else the Caps Lock chip (amber) when it's on.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(noteText.implicitWidth, capsChip.width)
            height: Theme.px(28)
            Text {
                id: noteText
                anchors.centerIn: parent
                visible: root.note !== ""
                text: root.note
                color: Theme.alpha(Theme.textOnError, 0.9)
                font.family: Theme.font
                font.pixelSize: Theme.px(13)
            }
            Rectangle {
                id: capsChip
                anchors.centerIn: parent
                property bool on: Keyboard.capsLock && root.note === "" && !root.passwordless
                opacity: on ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
                transform: Translate { y: capsChip.on ? 0 : -Theme.px(6); Behavior on y { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } } }
                width: capsRow.implicitWidth + Theme.px(24)
                height: Theme.px(28)
                radius: height / 2
                color: Theme.alpha(Theme.warningContainer, 0.6)
                border.width: 1
                border.color: Theme.alpha(Theme.warning, 0.5)
                Row {
                    id: capsRow
                    anchors.centerIn: parent
                    spacing: Theme.px(7)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "caps-lock"
                        size: Theme.px(13)
                        strokeWidth: 2.4
                        color: Theme.textOnWarning
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Caps Lock is on · layout " + Keyboard.short
                        color: Theme.textOnWarning
                        font.family: Theme.font
                        font.pixelSize: Theme.px(12.5)
                    }
                }
            }
        }
    }

    // --- Bottom-left: the user chip (greeter, several users)
    Row {
        id: leftChips
        x: Theme.px(32)
        y: root.height - Theme.px(28) - height
        spacing: Theme.px(10)
        visible: root.usersShown
        opacity: root.inChips * (1 - root.outChips)
        transform: Translate { y: Theme.px(12) * (1 - root.inChips + root.outChips) }

        SessionChip {
            id: userChip
            padLeft: Theme.px(5)
            lit: userMenu.shown
            onClicked: root.toggleUsers()
            Avatar {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(34)
                height: width
                source: root.users[root.userIndex]?.face ?? ""
                fallback: root.users[root.userIndex]?.guest ? "" : Theme.wallpaper
                letter: (root.users[root.userIndex]?.display ?? "?").charAt(0)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.users[root.userIndex]?.display ?? ""
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.px(13.5)
                font.weight: Font.Medium
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: userMenu.shown ? "chevron-down" : "chevron-up"
                size: Theme.px(14)
                strokeWidth: 2.4
                color: userMenu.shown ? Theme.textOnContainer : Theme.textMuted
            }
        }
        KeyHint { anchors.verticalCenter: parent.verticalCenter; key: "Alt U"; visible: !userMenu.shown && opacity > 0 }
    }

    // --- Bottom-right: battery + power
    Row {
        id: rightChips
        x: root.width - Theme.px(32) - width
        y: root.height - Theme.px(28) - height
        spacing: Theme.px(10)
        opacity: root.inChips * (1 - root.outChips)
        transform: Translate { y: Theme.px(12) * (1 - root.inChips + root.outChips) }

        KeyHint { anchors.verticalCenter: parent.verticalCenter; key: "Alt P"; visible: !powerMenu.shown && opacity > 0 }
        SessionChip {
            visible: Battery.present
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(20)
                height: battIcon.height
                Icon {
                    id: battIcon
                    anchors.centerIn: parent
                    name: "battery"
                    size: Theme.px(16)
                }
                Rectangle {
                    readonly property real unit: battIcon.size / 24
                    x: battIcon.x + 5 * unit
                    y: battIcon.y + 9 * unit
                    width: Math.max(3, 14 * Battery.percent / 100) * unit
                    height: 6 * unit
                    radius: unit
                    color: Battery.percent <= 15 && !Battery.pluggedIn ? Theme.warning : Theme.text
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.percent + " %"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.px(13.5)
                font.features: { "tnum": 1 }
            }
        }
        SessionChip {
            square: Theme.px(44)
            lit: powerMenu.shown
            onClicked: root.togglePower()
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "power"
                size: Theme.px(16)
            }
        }
    }

    UserMenu {
        id: userMenu
        x: Theme.px(32)
        y: leftChips.y - Theme.px(10) - height
        users: root.users
        current: root.userIndex
        lastUsed: root.lastUsed
        onPicked: i => { root.userChosen(i); shown = false }
    }
    PowerOptions {
        id: powerMenu
        x: root.width - Theme.px(32) - width
        y: rightChips.y - Theme.px(10) - height
        onAct: kind => { shown = false; root.powerAction(kind) }
    }

    function toggleUsers() {
        if (!usersShown) return
        powerMenu.shown = false
        userMenu.shown = !userMenu.shown
        focusField()
    }
    function togglePower() {
        userMenu.shown = false
        powerMenu.shown = !powerMenu.shown
        focusField()
    }
    function submit() {
        if (status !== "") return
        if (input.text === "" && !passwordless) return
        submitted(input.text)
    }

    // --- Keys: a hidden field holds the password and everything else goes through its key handler.
    TextInput {
        id: input
        width: 1
        height: 1
        opacity: 0
        echoMode: TextInput.Password
        readOnly: root.status === "checking" || root.status === "wait" || root.passwordless
        enabled: root.active

        Keys.onPressed: event => {
            capsCheck.restart()
            if (event.key === Qt.Key_Alt) { KeyHints.held = true; return }
            if (event.modifiers & Qt.AltModifier) {
                if (event.key === Qt.Key_P) root.togglePower()
                else if (event.key === Qt.Key_U) root.toggleUsers()
                event.accepted = true
                return
            }
            if (powerMenu.shown) {
                if (event.key === Qt.Key_Escape) powerMenu.shown = false
                else powerMenu.key(event)
                event.accepted = true
                return
            }
            if (userMenu.shown) {
                const n = root.users.length
                if (event.key === Qt.Key_Down || event.key === Qt.Key_J) root.userChosen((root.userIndex + 1) % n)
                else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) root.userChosen((root.userIndex + n - 1) % n)
                else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) userMenu.shown = false
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Escape) {
                input.text = ""
                root.escaped()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.submit()
                event.accepted = true
            }
        }
        Keys.onReleased: event => { if (event.key === Qt.Key_Alt) KeyHints.held = false }
        onActiveFocusChanged: if (!activeFocus) KeyHints.held = false
    }
    // Caps Lock toggles in Hyprland a moment after the key event.
    Timer {
        id: capsCheck
        interval: 60
        onTriggered: Keyboard.refreshCaps()
    }
}
