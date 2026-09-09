pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The SSH phone book.
//
// `neu_ssh.sh` merges ~/.ssh/config with the optional, untracked
// ~/.config/neu/ssh.json and hands back one list; this owns the parsed result
// and the launch. No timer: a phone book is not telemetry, so it is read at
// startup and again whenever the panel opens, which is the only moment a stale
// entry could be noticed.
Singleton {
    id: root

    property var data: ({ targets: [] })

    readonly property var targets: data.targets || []
    readonly property int count: targets.length

    /** Distinct group names, in first-seen order, for the panel's headers. */
    readonly property var groups: {
        const seen = [];
        for (const t of targets)
            if (seen.indexOf(t.group || "") < 0)
                seen.push(t.group || "");
        return seen;
    }

    /** Headers are noise when everything is in one bucket. */
    readonly property bool grouped: groups.length > 1

    function inGroup(g) {
        return targets.filter(t => (t.group || "") === g);
    }

    function reload() {
        if (!proc.running)
            proc.running = true;
    }

    // Hostnames and usernames never need anything outside this, and the string
    // is about to be handed to a shell by way of Hyprland's exec dispatcher.
    // Anything stranger is a typo in a hand-edited config, not a host -- say so
    // rather than passing it on.
    function safe(s) {
        return typeof s === "string" && s.length > 0 && /^[A-Za-z0-9._@:-]+$/.test(s);
    }

    /** Open a terminal on this target. `ghostty` is hyprland.lua's terminal. */
    function connect(t) {
        if (!t || !safe(t.target)) {
            console.warn("Ssh: refusing to launch a target with odd characters:",
                         t ? t.target : "(none)");
            return;
        }
        const port = (t.port && String(t.port).match(/^[0-9]+$/)) ? ` -p ${t.port}` : "";
        Hypr.exec(`ghostty -e ssh${port} '${t.target}'`);
    }

    Process {
        id: proc
        command: ["neu_ssh.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.data = JSON.parse(this.text || '{"targets":[]}');
                } catch (e) {
                    console.warn("Ssh: bad neu_ssh.sh output:", e);
                }
            }
        }
    }

    Component.onCompleted: root.reload()
}
