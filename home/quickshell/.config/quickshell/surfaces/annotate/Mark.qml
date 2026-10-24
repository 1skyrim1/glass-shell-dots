import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.services

// One annotation (23-Annotate), drawn in image pixels inside the editor's scene so the export is 1:1.
// mark = { kind: arrow | rect | pen | text | highlight | blur, color, size (stroke in image px),
//          x1, y1, x2, y2 (drag start / end), points ([[x, y], …] for pen), text }
Item {
    id: root

    required property var mark
    property Item base          // the screenshot Image (blur reads it)
    property bool editing: false
    signal textEdited(string text)
    signal editDone()

    readonly property string kind: mark.kind
    readonly property real l: Math.min(mark.x1, mark.x2)
    readonly property real t: Math.min(mark.y1, mark.y2)
    readonly property real w: Math.abs(mark.x2 - mark.x1)
    readonly property real h: Math.abs(mark.y2 - mark.y1)
    // Bounding box in image px, for selection and hit tests.
    readonly property rect box: kind === "text" ? Qt.rect(mark.x1, mark.y1, chip.width, chip.height)
        : kind === "pen" ? penBox : Qt.rect(l, t, w, h)
    readonly property rect penBox: {
        const p = mark.points ?? []
        if (p.length === 0) return Qt.rect(0, 0, 0, 0)
        const xs = p.map(q => q[0]), ys = p.map(q => q[1])
        const x = Math.min(...xs), y = Math.min(...ys)
        return Qt.rect(x, y, Math.max(...xs) - x, Math.max(...ys) - y)
    }
    // Text on a light chip is dark.
    readonly property color ink: Qt.colorEqual(mark.color, Theme.markWhite) || Qt.colorEqual(mark.color, Theme.markYellow)
        ? Theme.markBlack : Theme.markWhite

    // --- Rectangle: stroke, rounded like the design's 14 px at 4 px stroke.
    Rectangle {
        visible: root.kind === "rect"
        x: root.l
        y: root.t
        width: root.w
        height: root.h
        radius: root.mark.size * 3.5
        color: "transparent"
        border.width: root.mark.size
        border.color: root.mark.color
    }

    // --- Highlight: the colour at 55 % over the text (design: yellow, multiply).
    Rectangle {
        visible: root.kind === "highlight"
        x: root.l
        y: root.t
        width: root.w
        height: root.h
        radius: root.mark.size
        color: Theme.alpha(root.mark.color, 0.5)
    }

    // --- Blur: the screenshot under the box, blurred hard (hides a private tab, a token, …).
    Item {
        visible: root.kind === "blur" && root.w > 0 && root.h > 0
        x: root.l
        y: root.t
        width: root.w
        height: root.h
        clip: true
        ShaderEffectSource {
            id: under
            anchors.fill: parent
            sourceItem: root.kind === "blur" ? root.base : null
            sourceRect: Qt.rect(root.l, root.t, root.w, root.h)
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: under
            blurEnabled: true
            blur: 1
            blurMax: 64
            autoPaddingEnabled: false
        }
    }

    // --- Arrow and pen: stroked paths with round ends.
    Shape {
        visible: root.kind === "arrow" || root.kind === "pen"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.mark.color
            strokeWidth: root.mark.size
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline {
                path: {
                    const m = root.mark
                    if (root.kind === "pen") return (m.points ?? []).map(p => Qt.point(p[0], p[1]))
                    if (root.kind !== "arrow") return []
                    // Shaft plus a head of two strokes at ±28°, 4.5 × the stroke long.
                    const a = Math.atan2(m.y2 - m.y1, m.x2 - m.x1), len = m.size * 4.5, s = 0.49
                    const end = Qt.point(m.x2, m.y2)
                    return [Qt.point(m.x1, m.y1), end,
                            Qt.point(m.x2 - len * Math.cos(a - s), m.y2 - len * Math.sin(a - s)), end,
                            Qt.point(m.x2 - len * Math.cos(a + s), m.y2 - len * Math.sin(a + s))]
                }
            }
        }
    }

    // --- Text label on a chip of the colour (design: padding 8 / 14, radius 10, 20 px 600).
    Rectangle {
        id: chip
        visible: root.kind === "text"
        x: root.mark.x1
        y: root.mark.y1
        readonly property real fs: root.mark.size * 5
        width: label.implicitWidth + fs * 1.4
        height: label.implicitHeight + fs * 0.8
        radius: fs / 2
        color: root.mark.color
        TextInput {
            id: label
            anchors.centerIn: parent
            text: root.mark.text ?? ""
            readOnly: !root.editing
            font.family: Theme.font
            font.pixelSize: chip.fs
            font.weight: Font.DemiBold
            color: root.ink
            selectionColor: Theme.alpha(Theme.accent, 0.4)
            cursorVisible: root.editing
            onTextEdited: root.textEdited(text)
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Escape) {
                    root.editDone()
                    e.accepted = true
                }
            }
        }
    }
    function stopEditing() { label.focus = false }
    function startEditing() {
        label.forceActiveFocus()
        label.cursorPosition = label.text.length
    }
}
