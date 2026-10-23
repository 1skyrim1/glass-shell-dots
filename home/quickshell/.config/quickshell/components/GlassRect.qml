import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.services

// The one glass material (DESIGN.md §1.2). Fill, border, highlights and shadow are drawn here; the blur
// behind comes from Hyprland's layer rules (hyprland.lua), so the window's namespace must start with
// "glass-shell-".
//
// Children go inside. The interaction flags follow the pill states in 10-Popovers (bottom row):
// rest · hovered · pressed · lit (its panel is open / toggled on) · focused (keyboard) · enabled.
Item {
    id: root

    property string variant: "pill"          // "pill" | "popover" | "panel" | "dialog"
    property string strength: Config.glass   // "subtle" | "balanced" | "heavy"
    property bool lit: false
    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    // Cursor x while hovered (Pill sets it): the specular top edge brightens around it (Liquid Glass).
    property real hoverX: width / 2
    // Tinted pills (§2): "accent" (same as lit) | "error" (recording) | "warning" (low battery) | "success" (sharing).
    // toneMix blends from plain glass into the tone; the split pills animate it while they bud off the clock.
    property string tone: ""
    property real toneMix: 1
    property bool smoothColor: true   // off while toneMix animates the colour every frame

    property real radius: variant === "pill" ? height / 2
                        : variant === "popover" ? Theme.px(22)
                        : variant === "dialog" ? Theme.px(30) : Theme.px(26)

    default property alias content: inner.data

    // Recipe per strength, for a pill. fill = surface alpha; border / highlight / bottom = white alpha.
    // shadow scales the variant's shadow: heavy's blur threshold (ignore_alpha in hyprland.lua) has to sit
    // under its 6 % fill, so a normal shadow would get blurred and brightened into a halo.
    readonly property var recipes: ({
        subtle:   { fill: 0.82, border: 0.08, highlight: 0.00, bottom: 0.04, shadow: 1.0 },
        balanced: { fill: 0.44, border: 0.13, highlight: 0.20, bottom: 0.04, shadow: 1.0 },
        heavy:    { fill: 0.06, border: 0.35, highlight: 0.55, bottom: 0.04, shadow: 0.06 }
    })
    // Panels and dialogs are denser than pills and cast a bigger shadow. Fill scales relative to the
    // balanced recipe (44 % → 55 % / 58 %); border and highlight add on top. Shadow values are design px.
    readonly property var variants: ({
        pill:    { fill: 1.00,      border: 0.00, highlight: 0.00, shadowY: 10, shadowBlur: 34,  shadow: 0.38 },
        popover: { fill: 0.55 / 0.44, border: 0.03, highlight: 0.04, shadowY: 24, shadowBlur: 60,  shadow: 0.45 },
        panel:   { fill: 0.55 / 0.44, border: 0.03, highlight: 0.04, shadowY: 30, shadowBlur: 80,  shadow: 0.50 },
        dialog:  { fill: 0.58 / 0.44, border: 0.03, highlight: 0.04, shadowY: 40, shadowBlur: 100, shadow: 0.60 }
    })
    readonly property var r: recipes[strength] ?? recipes.balanced
    readonly property var v: variants[variant] ?? variants.pill

    readonly property string activeTone: tone !== "" ? tone : lit ? "accent" : ""
    readonly property bool tinted: activeTone !== "" && toneMix > 0.5
    readonly property var tones: ({
        accent:  { fill: Theme.alpha(Theme.accentContainer, 0.6), border: Theme.alpha(Theme.accent, 0.5) },
        error:   { fill: Theme.alpha(Theme.errorContainer, 0.45), border: Theme.alpha(Theme.error, 0.45) },
        warning: { fill: Theme.warningContainer, border: Theme.alpha(Theme.warning, 0.45) },
        success: { fill: Theme.successContainer, border: Theme.successBorder }
    })
    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
    }

    // Hover lightens toward the accent container, press darkens (values from Popovers.dc.html).
    readonly property color glassFill: pressed ? Theme.alpha(Qt.darker(Theme.glassTint, 1.6), Math.min(1, r.fill * v.fill + 0.16))
        : hovered ? Theme.alpha(Qt.tint(Theme.glassTint, Theme.alpha(Theme.accentContainer, 0.55)), Math.min(1, r.fill * v.fill + 0.11))
        : Theme.alpha(Theme.glassTint, Math.min(0.92, r.fill * v.fill))
    readonly property color glassBorder: Theme.white(r.border + v.border)
    readonly property color fillColor: activeTone === "" ? glassFill
        : mix(glassFill, Qt.lighter(tones[activeTone].fill, hovered && !pressed ? 1.25 : 1), toneMix)
    readonly property color borderColor: activeTone === "" ? glassBorder : mix(glassBorder, tones[activeTone].border, toneMix)
    readonly property real highlightAlpha: r.highlight === 0 ? 0
        : tinted ? 0.22 : r.highlight + v.highlight + (hovered && !pressed ? 0.06 : 0)

    // Disabled = 45 %. The animation sits on `dim`, not on opacity: surfaces that drive opacity every frame
    // (fades, grows) would restart an opacity Behavior each frame and it would never move.
    property real dim: enabled ? 1 : 0.45
    Behavior on dim { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
    opacity: dim
    scale: pressed ? 0.95 : hovered ? 1.04 : 1
    // Press squishes quickly; release springs back past the target (~102 % on the way to 100 %).
    Behavior on scale {
        NumberAnimation {
            duration: Motion.micro * (root.pressed ? 1 : 2)
            easing.type: root.pressed || Motion.reduced ? Motion.easeMicro : Easing.OutBack
            easing.overshoot: 2.2
        }
    }

    // --- Shadow, cut out under the shape so it doesn't darken the translucent glass (like CSS box-shadow).
    readonly property real shadowPad: Theme.px(v.shadowBlur + v.shadowY)
    Item {
        id: shadowSource
        anchors.fill: parent
        anchors.margins: -root.shadowPad
        visible: false
        layer.enabled: true
        RectangularShadow {
            x: root.shadowPad; y: root.shadowPad
            width: root.width; height: root.height
            radius: root.radius
            offset.y: Theme.px(root.v.shadowY * (root.hovered && !root.pressed ? 1.4 : 1))
            blur: Theme.px(root.v.shadowBlur)
            color: Qt.rgba(0, 0, 0, (root.v.shadow + (root.hovered && !root.pressed ? 0.04 : 0)) * root.r.shadow)
            Behavior on offset.y { NumberAnimation { duration: Motion.micro } }
        }
    }
    Item {
        id: shapeMask
        anchors.fill: shadowSource
        visible: false
        layer.enabled: true
        Rectangle { x: root.shadowPad; y: root.shadowPad; width: root.width; height: root.height; radius: root.radius }
    }
    MultiEffect {
        anchors.fill: shadowSource
        source: shadowSource
        maskEnabled: true
        maskInverted: true
        maskSource: shapeMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    // --- Keyboard focus
    FocusRing {
        shown: root.focused
        shapeRadius: root.radius
    }

    // --- Fill + 1 px border
    Rectangle {
        id: body
        anchors.fill: parent
        radius: root.radius
        color: root.fillColor
        border.width: 1
        border.color: root.focused ? "transparent" : root.borderColor
        Behavior on color { enabled: root.smoothColor; ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
        Behavior on border.color { enabled: root.smoothColor; ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
    }

    // --- Heavy: faint accent glow along the bottom.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.strength === "heavy" && !root.tinted
        gradient: Gradient {
            GradientStop { position: 0.55; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.alpha(Theme.accent, 0.14) }
        }
    }

    // --- Inset highlights, like CSS `inset 0 ±1px 0 white`: only the sliver between the inner shape and
    //     the same shape moved 1 px, so it's a hairline at the top (bottom) centre that thins out to nothing
    //     along the curve. Drawn as two rounded rects filled even-odd, clipped to that half of the shape.
    component EdgeLight: Item {
        id: light
        property real shift: 1   // +1 = top edge, -1 = bottom edge
        property bool spot: false   // only around hoverX, fading out to the sides
        anchors { left: parent.left; right: parent.right }
        height: root.height / 2
        y: shift > 0 ? 0 : root.height / 2
        clip: true
        Shape {
            y: -light.y
            width: root.width
            height: root.height
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillRule: ShapePath.OddEvenFill
                fillColor: "white"
                fillGradient: light.spot ? spotGradient : null
                strokeColor: "transparent"
                PathRectangle { x: 1; y: 1; width: root.width - 2; height: root.height - 2; radius: Math.max(0, root.radius - 1) }
                PathRectangle { x: 1; y: 1 + light.shift; width: root.width - 2; height: root.height - 2; radius: Math.max(0, root.radius - 1) }
            }
        }
    }
    EdgeLight {
        shift: 1
        opacity: root.highlightAlpha
        Behavior on opacity { NumberAnimation { duration: Motion.micro } }
    }
    // Hover: a brighter spot on the top edge that follows the cursor.
    RadialGradient {
        id: spotGradient
        centerX: root.hoverX; centerY: 0
        focalX: root.hoverX; focalY: 0
        centerRadius: Math.max(root.height * 2, root.width * 0.35)
        GradientStop { position: 0; color: "white" }
        GradientStop { position: 1; color: "transparent" }
    }
    EdgeLight {
        spot: true
        visible: root.r.highlight > 0 && !root.tinted
        opacity: root.hovered && !root.pressed ? 0.5 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.micro } }
    }
    EdgeLight {
        shift: -1
        opacity: root.tinted ? 0 : root.r.bottom
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
