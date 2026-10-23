import QtQuick
import qs.services

// Pill text (DESIGN.md §1.3): Geist 13 px on one line, cut with … when `width` is limited.
Text {
    color: Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.px(13)
    elide: Text.ElideRight
    maximumLineCount: 1
    Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
}
