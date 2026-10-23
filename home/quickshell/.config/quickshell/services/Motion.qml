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
    // A duration given exactly in §5.3 (open or close), still a 150 ms fade under reduced motion.
    function fixed(ms: int): int { return reduced ? reducedFade : ms }

    readonly property bool shake: !reduced

    // Bar (§5.3)
    readonly property int pillWidth: 220     // a pill's width follows its content
    readonly property int wsCapsule: 260     // active capsule stretches to the new dot, then lets go
    readonly property int wsTitle: 180       // old title blurs out upward, new one rises in
    readonly property int mediaIn: 320       // media pill slides out from behind the workspace pill (OutBack)
    readonly property int mediaOut: 220      // … and tucks back (InCubic)
    readonly property int mediaTuck: 10000   // that long after playback stops
    readonly property int splitIn: 380       // recording / sharing / key-mode pill buds off the clock
    readonly property int splitOut: 300      // … and merges back
    readonly property int osdIn: 300         // OSD drops out of the clock
    readonly property int osdOut: 240        // … and is pulled back up
    readonly property int osdStep: 120       // each further press only moves the fill
    readonly property int osdHold: 1200      // after the last press
    readonly property int warnHold: 5000     // low-battery tint on the status pill
    readonly property int eqPeriod: 1400     // media pill equalizer bars (up and down)

    // Value of a keyframed curve at t (0…1). keys = [[t, value], …] with t ascending, like the CSS
    // @keyframes in design/source/Motion*.dc.html; each segment eases in and out. Past either end the
    // first / last segment continues linearly, so an OutBack progress overshoots the shape too.
    function frames(t: real, keys: var): real {
        const n = keys.length
        if (t <= keys[0][0] || t >= keys[n - 1][0]) {
            const [a, b] = t <= keys[0][0] ? [keys[0], keys[1]] : [keys[n - 2], keys[n - 1]]
            const end = t <= keys[0][0] ? a : b
            return end[1] + (t - end[0]) * (b[1] - a[1]) / (b[0] - a[0])
        }
        let i = 1
        while (t > keys[i][0]) i++
        const [t0, v0] = keys[i - 1], [t1, v1] = keys[i]
        const u = (t - t0) / (t1 - t0)
        return v0 + (v1 - v0) * u * u * (3 - 2 * u)
    }
}
