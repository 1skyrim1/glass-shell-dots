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

    // Launcher and cheatsheet (§5.3)
    readonly property int launcherIn: 400    // drips out of the clock and springs into the centre
    readonly property int launcherOut: 240   // … and is sucked back into it
    readonly property int sheetMorph: 300    // launcher ↔ cheatsheet, panel height following its content
    readonly property int stagger: 35        // rows arrive this far apart

    // Control Center (§5.3, 01-MotionControl, 04-MotionOverlays "Control Center sub-page")
    readonly property int controlIn: 400     // grows out of the status pill
    readonly property int controlOut: 220    // … and snaps back into it
    readonly property int push: 300          // sub-page slides in, panel height springs to fit
    readonly property int spinner: 900       // one turn of a "Searching…" spinner

    // Notifications (§3.5, §5.3; 02-MotionLauncher toBlob, 04-MotionOverlays nc + toast fan)
    readonly property int notifIn: 420       // center drips out of the clock, two columns fade up
    readonly property int notifOut: 240      // … and is pulled back into it
    readonly property int columnStagger: 40  // the list column fades up this much after the calendar
    readonly property int toastIn: 300       // bell widens along the top, drops into the toast
    readonly property int toastOut: 240      // … merges back into the bell, leaving a dot
    readonly property int toastFan: 240      // hovering the stack fans it out / tucks it back
    readonly property int toastShort: 5000   // a toast's timer
    readonly property int toastLong: 10000   // … when it has actions (critical: never)
    readonly property int replySent: 1000    // "Sent ✓" shows this long, then the card collapses

    // Wallpaper switcher (§3.6, §5.3; 07-MotionWallpaper)
    readonly property int wallSheetIn: 320   // the strip rises from below the screen, 10 px past its place
    readonly property int wallSheetOut: 190  // … and sinks away
    readonly property int themeFade: 240     // every colour cross-fades to the next palette (browse, Esc)
    readonly property int ripple: 700        // Enter: the new wallpaper spreads out from the thumbnail (InOutCubic)
    readonly property int kittyPreview: 150  // browsing pauses this long before kitty is recoloured

    // Capture (§3.7, §5.3; 04-MotionOverlays "Capture", 24-CaptureExtras)
    readonly property int captureFlash: 80     // soft white flash on freeze and on capture
    readonly property int captureDim: 200      // the frozen screen dims
    readonly property int toolbarRise: 320     // toolbar rises from below (OutBack), after the dim
    readonly property int captureFly: 300      // the selection flies into the corner thumbnail
    readonly property int shotCardHold: 6000   // the thumbnail card waits this long
    readonly property int countdownTick: 1000  // one number of the countdown; its red ring drains meanwhile

    // Popovers (§3.1)
    readonly property int peekDelay: 400     // hover a workspace dot this long to peek
    readonly property int peekGrace: 250     // the mouse may leave dot + peek this long (to cross the gap)
    readonly property int tipDelay: 600      // hover an icon this long for its tooltip

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
