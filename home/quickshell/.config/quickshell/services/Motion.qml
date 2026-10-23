pragma Singleton
import QtQuick
import Quickshell

// Motion system (DESIGN.md §5.1). Every duration and easing goes through here.
Singleton {
    readonly property bool reduced: Config.reducedMotion

    // Durations (ms)
    readonly property int micro: 120   // hover, press, toggle, colour change
    readonly property int small: 200   // popovers, tooltips, OSD fill, title cross-fade (180–220)
    readonly property int medium: 400  // launcher, Control Center, notification center, sheets (320–420)
    readonly property int large: 600   // lock, log in, wallpaper ripple, overview zoom (450–700)
    readonly property real closeFactor: 0.6
    readonly property int reducedFade: 150

    // Easings
    readonly property int easeMicro: Easing.OutCubic
    readonly property int easeSmall: Easing.OutCubic
    readonly property int easeOpen: reduced ? Easing.OutCubic : Easing.OutBack
    readonly property real overshoot: reduced ? 0 : 1.15
    readonly property int easeLarge: Easing.InOutCubic
    readonly property int easeClose: Easing.InCubic

    // Grows, splits and morphs: with reduced motion they all become a 150 ms fade.
    function open(ms: int): int { return reduced ? reducedFade : ms }
    function close(ms: int): int { return reduced ? reducedFade : Math.round(ms * closeFactor) }

    readonly property bool shake: !reduced
}
