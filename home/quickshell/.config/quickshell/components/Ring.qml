import QtQuick
import QtQuick.Shapes
import qs.services

// A progress ring like the design's SVG circles (r 9 in a 24 box): a faint track plus an arc from the top,
// clockwise. `progress` is the drawn fraction; `spinning` turns it into a quarter arc that goes round
// (checking password, the go button's spinner).
Item {
    id: root

    property real progress: 1
    property bool spinning: false
    property color color: Theme.accent
    property color track: Theme.alpha(color, 0.25)
    property real stroke: 3   // in the 24 box's units

    readonly property real u: width / 24
    implicitWidth: Theme.px(16)
    implicitHeight: implicitWidth
    height: width

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.track
            strokeWidth: root.stroke * root.u
            fillColor: "transparent"
            PathAngleArc { centerX: 12 * root.u; centerY: 12 * root.u; radiusX: 9 * root.u; radiusY: 9 * root.u; sweepAngle: 360 }
        }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.spinning || root.progress > 0
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.stroke * root.u
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: 12 * root.u; centerY: 12 * root.u; radiusX: 9 * root.u; radiusY: 9 * root.u
                startAngle: -90
                sweepAngle: root.spinning ? 90 : 360 * Math.min(1, root.progress)
            }
        }
        RotationAnimation on rotation {
            from: 0; to: 360
            duration: Motion.spinner
            loops: Animation.Infinite
            running: root.spinning && root.visible
            onStopped: parent.rotation = 0
        }
    }
}
