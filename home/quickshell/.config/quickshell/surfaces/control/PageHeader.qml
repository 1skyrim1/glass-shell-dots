import QtQuick
import qs.services
import qs.components

// A sub-page's header (ControlPages.dc.html `.hd`): 30 px round back button, 15 px title, optional switch.
Item {
    id: root

    property string title
    property bool hasSwitch: false
    property bool checked: false

    signal back()
    signal toggled()

    width: parent?.width ?? 0
    implicitHeight: Theme.px(2 + 30 + 8)

    Button {
        id: back
        x: Theme.px(4)
        y: Theme.px(2)
        width: Theme.px(30)
        height: width
        base: Theme.white(0.08)
        onClicked: root.back()
        Icon { anchors.centerIn: parent; name: "chevron-left"; size: Theme.px(16); strokeWidth: 2.2 }
    }
    Text {
        anchors { left: back.right; leftMargin: Theme.px(10); verticalCenter: back.verticalCenter }
        text: root.title
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.px(15)
        font.weight: Font.DemiBold
    }
    Switch {
        visible: root.hasSwitch
        anchors { right: parent.right; rightMargin: Theme.px(4); verticalCenter: back.verticalCenter }
        checked: root.checked
        onToggled: root.toggled()
    }
}
