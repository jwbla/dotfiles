pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Local dev state for the Dev Hub. Complements Rgtv (SUPER+R), which answers
// "what is the fleet doing"; this answers "what am I in the middle of".
//
// Polls only while the panel is open -- it shells out to git once per repo.
Singleton {
    id: root

    property var repos: []
    property var sessions: []
    property bool loading: false
    property bool live: false

    readonly property int dirtyCount: repos.filter(r => r.dirty > 0).length
    readonly property int aheadCount: repos.filter(r => r.ahead > 0).length

    function reload() {
        if (proc.running)
            return;
        loading = true;
        proc.running = true;
    }

    function open(repo) {
        // Attach or create a tmux session named after the repo, in a terminal.
        const cmd = "ghostty -e tmux new-session -A -s " + repo.name + " -c " + repo.path;
        openProc.command = ["hyprctl", "dispatch", "exec", cmd];
        openProc.running = true;
    }

    Process {
        id: proc
        command: ["neu_devhub.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text || "{}");
                    // Most-in-flight first: dirty repos, then most recently touched.
                    root.repos = (d.repos || []).sort((a, b) =>
                        (b.dirty > 0) - (a.dirty > 0) || a.ageDays - b.ageDays
                        || a.name.localeCompare(b.name));
                    root.sessions = d.sessions || [];
                } catch (e) {
                    console.warn("Dev: bad neu_devhub.sh output:", e);
                }
                root.loading = false;
            }
        }
    }

    Process { id: openProc }

    Timer {
        interval: 30000
        repeat: true
        running: root.live
        onTriggered: root.reload()
    }
}
