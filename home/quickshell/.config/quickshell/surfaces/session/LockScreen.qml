import QtQuick
import QtQuick.Effects
import Quickshell
import qs.services

// The lock screen on one screen (28-Lock, 29-LockPower, 30-SessionStates): the desktop as it was when it
// locked (Session froze it with grim), blurred 30 and darkened to 62 % as the lock comes in, with the shared
// SessionView on top. Session-lock surfaces get no Hyprland blur, hence the frozen frame blurred here.
Item {
    id: root

    required property string screenName

    // How locked it looks: blur + darkening come in with the lock and clear with the unlock.
    readonly property real veil: Math.min(1, Session.lockT / 0.67) * (1 - Session.leaveT)

    Rectangle {
        anchors.fill: parent
        color: "black"
    }
    // The frozen frame, sharp, and a heavily blurred copy over it that fades in with the lock (CSS blur 30 +
    // saturate 1.2).
    Image {
        id: shot
        anchors.fill: parent
        source: Session.shotId > 0 ? Session.shotOf(root.screenName) : ""
        cache: false
    }
    // The blur works on a 1/4-size copy: cheaper, and it reaches as far as CSS blur(30px).
    // (opacity 0, not visible: false, or it stops updating when the frame loads.)
    ShaderEffectSource {
        id: small
        anchors.fill: parent
        sourceItem: shot
        textureSize: Qt.size(Math.round(root.width / 4), Math.round(root.height / 4))
        smooth: true
        opacity: 0
    }
    MultiEffect {
        anchors.fill: parent
        source: small
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: 1
        saturation: 0.2
        opacity: root.veil
    }
    // brightness(.62)
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.38 * root.veil
    }

    SessionView {
        anchors.fill: parent
        mode: "lock"
        displayName: Session.user
        face: Quickshell.env("HOME") + "/.face"
        faceFallback: Theme.wallpaper
        status: Session.status
        note: Session.status === "wait"
            ? `${root.ordinal(Session.failures)} attempt · wait ${Session.waitLeft} s before trying again` : ""
        enterT: Session.lockT
        leaveT: Session.leaveT
        leaveKind: "unlock"
        onSubmitted: password => Session.submit(password)
        onPowerAction: kind => kind === "suspend" ? Session.suspend() : Session.end(kind)
        onEscaped: {
            if (Session.ending !== "") Session.cancelEnd()
            else if (Session.preview) Session.unlock()
        }
    }

    EndingView { anchors.fill: parent }

    function ordinal(n: int): string {
        const s = n % 100 >= 11 && n % 100 <= 13 ? "th" : (["th", "st", "nd", "rd"][n % 10] ?? "th")
        return n + s
    }
}
