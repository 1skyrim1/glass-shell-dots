import QtQuick
import qs.services
import qs.components

// A Control Center toggle tile (Control.dc.html `.wide` / `.sm`). Wide: 62 px, icon + title + subtitle +
// a › that opens its page (the body toggles). Small: 64 px, icon over an 11.5 px label. On = accent fill;
// off = white 8 %. The number (its 1–8 key) shows top-right while Alt is held.
// `arrive` is the stagger: the Control Center runs it from 0 to 1, `order` × 35 ms after the content shows.
// It sits on this wrapper, not on the Button, whose opacity has its own Behavior.
Item {
    id: root

    property bool wide: false
    property string icon
    property string title
    property string subtitle
    property bool on: false
    property string number
    property bool chevron: wide
    property bool focused: false
    // Night light grows into a card in place (NightLightCard on top); the tile's own content fades out.
    property bool expanded: false
    property color tint: on ? Theme.accent : Theme.white(0.08)
    readonly property color ink: on ? Theme.textOnAccent : Theme.text
    default property alias content: button.content

    signal clicked()
    signal opened()   // the › (or Enter on a wide tile)

    property int order: 0
    property real arrive: 1
    function enter(run: bool) {
        stagger.stop()
        arrive = run ? 0 : 1
        if (run) stagger.start()
    }
    SequentialAnimation {
        id: stagger
        PauseAnimation { duration: root.order * Motion.stagger }
        NumberAnimation { target: root; property: "arrive"; to: 1; duration: Motion.small; easing.type: Motion.easeSmall }
    }
    opacity: arrive
    transform: Translate { y: Theme.px(8) * (1 - root.arrive) }

    Button {
        id: button
        anchors.fill: parent
        radius: Theme.px(18)
        base: root.tint
        focused: root.focused
        hoverScale: root.wide ? 1.02 : 1.04
        onClicked: root.clicked()

        Item {
            anchors.fill: parent
            opacity: root.expanded ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }

            // Wide: icon, title / subtitle, ›
            Row {
                visible: root.wide
                anchors { left: parent.left; leftMargin: Theme.px(14); right: parent.right; rightMargin: Theme.px(14); verticalCenter: parent.verticalCenter }
                spacing: Theme.px(10)
                Icon { anchors.verticalCenter: parent.verticalCenter; name: root.icon; size: Theme.px(16); color: root.ink }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.px(16) * 2 - parent.spacing * 2
                    Text {
                        width: parent.width
                        text: root.title
                        color: root.ink
                        font.family: Theme.font
                        font.pixelSize: Theme.px(13)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: root.subtitle
                        color: root.ink
                        font.family: Theme.font
                        font.pixelSize: Theme.px(11.5)
                        elide: Text.ElideRight
                    }
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.chevron
                    name: "chevron-right"
                    size: Theme.px(16)
                    strokeWidth: 2.2
                    color: root.ink
                }
            }

            // Small: icon above the label, bottom-left
            Column {
                visible: !root.wide
                anchors { left: parent.left; leftMargin: Theme.px(12); right: parent.right; bottom: parent.bottom; bottomMargin: Theme.px(10) }
                spacing: Theme.px(4)
                Icon { name: root.icon; size: Theme.px(16); color: root.ink }
                Text {
                    width: parent.width
                    text: root.title
                    color: root.ink
                    font.family: Theme.font
                    font.pixelSize: Theme.px(11.5)
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }

            Text {
                anchors { top: parent.top; topMargin: Theme.px(7); right: parent.right; rightMargin: Theme.px(8) }
                text: root.number
                color: root.ink
                font.family: Theme.fontMono
                font.pixelSize: Theme.px(10)
                opacity: KeyHints.held ? 0.7 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
            }
        }

        // The › area opens the page; the rest of the tile toggles.
        MouseArea {
            visible: root.chevron && !root.expanded
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            width: Theme.px(44)
            onClicked: root.opened()
        }
    }
}
