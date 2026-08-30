pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The application list for Spotlight.
//
// Quickshell's DesktopEntries model reports zero applications on this machine
// even with XDG_DATA_DIRS set correctly, so neu_apps.sh parses the .desktop
// files itself. It is read once at startup and on demand, not polled.
Singleton {
    id: root

    property var apps: []
    property bool loaded: false

    function reload() {
        if (!proc.running)
            proc.running = true;
    }

    function launch(app) {
        if (!app || !app.exec)
            return;
        // Detach: the launched program must outlive the shell that started it.
        launcher.command = app.terminal
            ? ["hyprctl", "dispatch", "exec", "ghostty -e " + app.exec]
            : ["hyprctl", "dispatch", "exec", app.exec];
        launcher.running = true;
    }

    Process {
        id: proc
        command: ["neu_apps.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.apps = JSON.parse(this.text || "[]");
                    root.loaded = true;
                } catch (e) {
                    console.warn("Apps: could not parse neu_apps.sh output:", e);
                    root.apps = [];
                }
            }
        }
    }

    Process { id: launcher }

    Component.onCompleted: reload()
}
