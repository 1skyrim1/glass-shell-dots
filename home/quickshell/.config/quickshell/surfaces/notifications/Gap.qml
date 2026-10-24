import QtQuick
import qs.services

// Vertical space in a Column that only takes room while the item after it is shown.
Item {
    property real size: 8   // design px
    property bool shown: true
    width: 1
    height: Theme.px(size)
    visible: shown
}
