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
        // Through Hypr, not a raw `hyprctl dispatch exec` -- this session's
        // Hyprland parses dispatches as Lua and rejected the plain form, which
        // is why launching from Spotlight was a coin flip. Hyprland execs it, so
        // the program outlives the shell that started it.
        Hypr.exec(app.terminal ? "ghostty -e " + app.exec : app.exec);
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

    Component.onCompleted: reload()
}
