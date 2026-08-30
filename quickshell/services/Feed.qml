import QtQuick
import Quickshell.Io

// One `rgtv_glance.sh <sub>` feed: runs the script, keeps the parsed JSON and
// the loading/error state. Setting `running` on an already-running Process is
// a no-op, so a slow source cannot stack up processes under the 30s poll.
//
// A failed run keeps the previous `data` (stale beats blank) and exposes the
// script's stderr as `error` so the pane can say why.
QtObject {
    id: root

    required property string sub

    // What `data` holds before the first successful load.
    property var fallback: []

    property var data: fallback
    property bool loading: false
    property bool loaded: false
    property string error: ""
    property date updatedAt: new Date(0)

    signal finished()

    function reload() {
        proc.running = true;
    }

    property string _parseError: ""

    property Process proc: Process {
        id: proc

        command: ["rgtv_glance.sh", root.sub]

        onStarted: root.loading = true

        stdout: StdioCollector {
            onStreamFinished: {
                const text = (this.text || "").trim();
                if (text === "")
                    return;
                try {
                    const parsed = JSON.parse(text);
                    root.data = parsed === null ? root.fallback : parsed;
                    root.loaded = true;
                    root.updatedAt = new Date();
                    root._parseError = "";
                } catch (e) {
                    root._parseError = `unparseable output: ${e}`;
                }
            }
        }

        stderr: StdioCollector {
            id: err
        }

        onExited: function (code) {
            root.loading = false;
            if (code !== 0)
                root.error = (err.text || "").trim() || `rgtv_glance.sh ${root.sub}: exit ${code}`;
            else
                root.error = root._parseError;
            if (root.error !== "")
                console.warn("Rgtv:", root.sub, root.error);
            root.finished();
        }
    }
}
