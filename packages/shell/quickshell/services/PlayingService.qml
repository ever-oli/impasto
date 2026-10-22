// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P L A Y I N G   S E R V I C E                                          │
// │   what is playing, and where it was left                                  │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The player in the island terminal writes what it is playing into
// ~/.local/state/notch/playing.json: the title, the place in the film,
// and the line that is being said. The shell reads it, shows the title
// and the progress on the bar, and keeps the titles it has watched so
// the catalogue can offer them again.
Singleton {
    id: root

    readonly property string stateDirectory: (Quickshell.env("XDG_STATE_HOME")
        || Quickshell.env("HOME") + "/.local/state") + "/notch"

    // What is playing now.
    property var playing: null
    // The titles that were watched, newest first.
    property var history: []
    // The line being said.
    property string caption: ""

    readonly property FileView playingFile: FileView {
        path: root.stateDirectory + "/playing.json"
        watchChanges: true

        onFileChanged: root.reload()
        onLoaded: root.reload()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.playing = null
        }

        JsonAdapter {
            id: playingJson

            property var title: ""
            property var caption: ""
            property var kind: ""
            property var mediaId: ""
            property var season: ""
            property var episode: ""
            property var position: 0
            property var duration: 0
            property var updated: 0
        }
    }

    readonly property FileView historyFile: FileView {
        path: root.stateDirectory + "/watching.json"
        watchChanges: true

        onFileChanged: root.reloadHistory()
        onLoaded: root.reloadHistory()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.history = []
        }

        JsonAdapter {
            id: historyJson

            property var items: []
        }
    }

    function reload(): void {
        if (!playingJson.title && !playingJson.caption) {
            root.playing = null
            root.caption = ""
            return
        }
        root.playing = {
            "title": playingJson.title || "",
            "caption": playingJson.caption || "",
            "kind": playingJson.kind || "",
            "mediaId": playingJson.mediaId || "",
            "season": playingJson.season || "",
            "episode": playingJson.episode || "",
            "position": playingJson.position || 0,
            "duration": playingJson.duration || 0,
            "updated": playingJson.updated || 0,
        }
        root.caption = playingJson.caption || ""
    }

    function reloadHistory(): void {
        const items = historyJson.items
        root.history = Array.isArray(items) ? items : []
    }

    // What the shell is playing, for anyone who asks.
    IpcHandler {
        target: "playing"

        function get(): string {
            // Every answer carries ok, like every other target, so a
            // caller that checks it does not read this as a failure.
            return JSON.stringify({
                ok: true,
                playing: root.playing,
                caption: root.caption,
                history: root.history.length,
            })
        }
    }

    Component.onCompleted: {
        root.reload()
        root.reloadHistory()
    }
}
