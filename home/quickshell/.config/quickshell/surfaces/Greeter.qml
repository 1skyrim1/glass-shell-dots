import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.surfaces.session

// The greeter on one screen (DESIGN.md §3.8 "Login", 26-Login, 27-LoginUsers), driven by services/Login.qml and
// started by greeter.qml inside the greeter's own Hyprland (system/etc/greetd/). Two layers, like the session:
// the wallpaper dimmed 22 % (not blurred), and the shared SessionView in a "glass-shell-" layer so the greeter
// Hyprland blurs the wallpaper behind its chips and popovers.
// Log in (06-MotionSession): spinner in the go button → avatar + field sink, chips drop, the clock flies into
// the clock pill's place and the dim lifts → greetd starts the session, whose bar drops its pills in.
// In test mode (GLASS_GREETER_TEST=1) both layers sit on Overlay, above the running session's bar.
Scope {
    id: root

    required property ShellScreen screen
    readonly property bool primary: screen === Quickshell.screens[0]
    readonly property var layer: Login.test ? WlrLayer.Overlay : WlrLayer.Background

    PanelWindow {
        screen: root.screen
        WlrLayershell.layer: root.layer
        WlrLayershell.namespace: "glass-greeter-wallpaper"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: Theme.glassTint

        Image {
            anchors.fill: parent
            source: Theme.wallpaper !== "" ? "file://" + Theme.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(width * 2, height * 2)
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.scrim, 0.22)
            opacity: 1 - Login.leaveT
        }
    }

    PanelWindow {
        screen: root.screen
        WlrLayershell.layer: Login.test ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.namespace: "glass-shell-greeter"
        WlrLayershell.keyboardFocus: root.primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        SessionView {
            anchors.fill: parent
            mode: "greeter"
            active: root.primary
            displayName: Login.user?.display ?? ""
            face: Login.user?.face ?? ""
            faceFallback: Login.user?.guest ? "" : Theme.wallpaper
            passwordless: Login.user?.guest ?? false
            users: Login.users
            userIndex: Login.index
            lastUsed: Login.lastUsed
            status: Login.status
            note: Login.waitNote
            leaveT: Login.leaveT
            leaveKind: "login"
            onSubmitted: password => Login.submit(password)
            onUserChosen: i => Login.select(i)
            onPowerAction: kind => Login.power(kind)
        }

        // Reboot / power off: fade to black.
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: Login.endT
        }
    }
}
