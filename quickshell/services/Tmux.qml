pragma Singleton

import Quickshell
import Quickshell.Io

// tms projects. _tms_list_projects in tmux-session-manager.sh is already what
// the fzf, television and wofi pickers consume, so it is sourced rather than
// re-parsing ~/.config/tms/projects/*.conf into a second implementation.
Singleton {
    id: root

    // [{ name, running }]
    property var projects: []

    function reload() {
        listProc.running = true;
    }

    function attach(name) {
        // tms-attach.sh creates the session if needed, then reuses an existing
        // ghostty via hyprctl instead of spawning a second terminal.
        attachProc.command = ["bash", "-c", 'exec ~/.local/bin/tms-attach.sh "$1"', "tms-attach", name];
        attachProc.running = true;
    }

    Process {
        id: listProc
        command: ["bash", "-c", "source ~/.config/tms/tmux-session-manager.sh; _tms_list_projects"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of (this.text || "").split("\n")) {
                    const t = line.trim();
                    if (t === "")
                        continue;
                    out.push({
                        running: t.startsWith("●"),
                        name: t.slice(1).trim()
                    });
                }
                root.projects = out;
            }
        }
    }

    Process {
        id: attachProc
        onExited: root.reload()
    }
}
