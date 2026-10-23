pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User settings from config.json (next to shell.qml, stowed from the repo). Edits reload live.
Singleton {
    id: root

    property alias glass: adapter.glass                  // "subtle" | "balanced" | "heavy" (§1.2)
    property alias reducedMotion: adapter.reducedMotion  // §5.2
    property alias idle: adapter.idle                    // seconds (§4 idle chain)

    FileView {
        path: Quickshell.shellDir + "/config.json"
        watchChanges: true
        // The file is a stow symlink into the repo; an atomic write would replace the link with a copy.
        atomicWrites: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter
            property string glass: "balanced"
            property bool reducedMotion: false
            property JsonObject idle: JsonObject {
                property int dimCountdown: 10
                property int lock: 300
                property int screenOff: 420
                property int suspendOnBattery: 900
            }
        }
    }
}
