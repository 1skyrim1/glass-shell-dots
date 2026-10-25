pragma Singleton
import QtQuick
import Quickshell

// True while Alt is held. Set by the Alt press/release binds in Hyprland's conf/binds.lua (via the keyhints IPC target).
Singleton {
    property bool held: false
}
