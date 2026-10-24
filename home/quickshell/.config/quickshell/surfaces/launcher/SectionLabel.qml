import QtQuick
import qs.services

// "BEST MATCH", "RECENT", … (DESIGN.md §1.3 section label): 11.5 px uppercase, letter-spacing 0.6, faint.
Text {
    property real above: Theme.px(12)
    property real below: Theme.px(5)
    width: parent?.width ?? implicitWidth
    topPadding: above
    bottomPadding: below
    leftPadding: Theme.px(2)
    color: Theme.textFaint
    font.family: Theme.font
    font.pixelSize: Theme.px(11.5)
    font.letterSpacing: Theme.px(0.6)
    font.capitalization: Font.AllUppercase
}
