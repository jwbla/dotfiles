pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Gitea Actions jobs running on this machine.
//
// Only the flagship laptop has runners on it -- a host-mode act_runner for the
// android/linux lanes and a docker-mode one for generic jobs -- so this is a
// service that reports nothing on every other box in this set, and the module
// it feeds draws nothing there. `neu_ci.sh` answers `present:false` after two
// stat calls when there is no registration file, and the timer below drops to a
// five-minute heartbeat on that answer: a bar module for one laptop should not
// be a poll on the rest.
//
// Kept out of Sys.qml deliberately. That singleton is one process per 3s for
// every machine, and folding a `docker ps` into it would put the docker daemon
// on the critical path of the battery icon.
Singleton {
    id: root

    property var data: ({ present: false, jobs: 0, runners: [] })

    readonly property bool present: !!data.present
    readonly property int jobs: data.jobs || 0
    readonly property var runners: data.runners || []
    /** The Gitea instance the runners are registered against. */
    readonly property string url: data.url || ""

    // What the bar actually draws, which is not `jobs` directly.
    //
    // A host-mode job is only visible while one of its steps holds a process,
    // so the count reads 0 for the moment between two steps and the icon would
    // blink out mid-run. Hold the last non-zero reading for a few seconds
    // instead: a CI run lasts minutes, and an icon that strobes through one is
    // worse than an icon that lingers a breath after it ends.
    property bool active: false
    property int shownJobs: 0

    /** Hover text: the total, then a line per runner. */
    readonly property string summary: {
        if (!present)
            return "";
        const n = jobs > 0 ? jobs : shownJobs;
        const head = n > 0
            ? `CI · ${n} job${n === 1 ? "" : "s"} running`
            : "CI · idle";
        const lines = runners.map(r =>
            `${r.name}: ${r.jobs}/${r.capacity > 0 ? r.capacity : "?"}${r.up ? "" : "  (runner down)"}`);
        return lines.length ? head + "\n" + lines.join("\n") : head;
    }

    function reload() {
        if (!proc.running)
            proc.running = true;
    }

    /** Open the Gitea the runners answer to. */
    function open() {
        if (url)
            Quickshell.execDetached(["xdg-open", url]);
    }

    onJobsChanged: {
        if (jobs > 0) {
            shownJobs = jobs;
            active = true;
            cooldown.stop();
        } else if (active) {
            cooldown.restart();
        }
    }

    Timer {
        id: cooldown
        interval: 8000
        onTriggered: root.active = false
    }

    Process {
        id: proc
        command: ["neu_ci.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.data = JSON.parse(this.text || "{}");
                } catch (e) {
                    console.warn("Ci: bad neu_ci.sh output:", e);
                }
            }
        }
    }

    // 4s while there is something here to watch. The five-minute heartbeat
    // otherwise exists only so that registering a runner does not also need a
    // shell restart to be noticed.
    Timer {
        interval: root.present ? 4000 : 300000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.reload()
    }
}
