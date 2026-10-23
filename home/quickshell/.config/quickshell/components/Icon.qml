import QtQuick
import QtQuick.Shapes
import qs.services
import "icons.js" as Icons

// A stroke icon from icons.js, drawn as vector paths so it stays sharp at any scale.
// `size` is the height; the width follows the icon's viewBox (24 wide unless the icon says otherwise).
Item {
    id: root

    property string name
    property real size: Theme.px(15)
    property color color: Theme.text
    property real strokeWidth: 2   // in viewBox units, like the SVG stroke-width

    readonly property var icon: Icons.get(name)
    readonly property real viewWidth: icon.w ?? 24

    implicitWidth: size * viewWidth / 24
    implicitHeight: size

    Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }

    Shape {
        width: root.viewWidth
        height: 24
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { xScale: root.size / 24; yScale: root.size / 24 }

        ShapePath {
            strokeColor: root.icon.fill ? "transparent" : root.color
            strokeWidth: root.icon.fill ? 0 : root.strokeWidth
            fillColor: root.icon.fill ? root.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.icon.d }
        }
    }
}
