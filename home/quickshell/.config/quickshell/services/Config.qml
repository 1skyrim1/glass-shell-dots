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
    property alias searchUrl: adapter.searchUrl          // launcher web search; the query is appended
    property alias nightLight: adapter.nightLight        // night light schedule, "HH:MM" local time

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
            property string searchUrl: "https://duckduckgo.com/?q="
            property JsonObject nightLight: JsonObject {
                property string from: "20:00"
                property string to: "07:00"
            }
            property JsonObject idle: JsonObject {
                property int dimCountdown: 10
                property int lock: 300
                property int screenOff: 420
                property int suspendOnBattery: 900
            }
        }
    }
}
