pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The window list, in most-recently-used order.
//
// Reads `hyprctl clients -j` rather than binding Quickshell's Hyprland.toplevels:
// that model reports zero entries on this machine (same as its Pipewire, UPower
// and DesktopEntries models), and `focusHistoryID` -- which is the whole basis of
// alt-tab ordering -- only exists in the IPC payload anyway.
Singleton {
    id: root

    property var windows: []

    /** Icon for a window class, borrowing the dock's mapping. */
    function iconFor(cls) {
        const c = (cls || "").toLowerCase();
        for (const p of DockConfig.pinned)
            if (p.wmClass && c === p.wmClass.toLowerCase())
                return p.icon;
        if (c.includes("code") || c.includes("nvim")) return Icons.code;
        if (c.includes("chrom") || c.includes("firefox") || c.includes("wolf"))
            return Icons.chrome;
        if (c.includes("term") || c.includes("ghostty") || c.includes("kitty"))
            return Icons.terminal;
        return Icons.app;
    }

    function reload() {
        if (!proc.running)
            proc.running = true;
    }

    function focus(addr) {
        focusProc.command = ["hyprctl", "dispatch", "focuswindow", "address:" + addr];
        focusProc.running = true;
    }

    Process {
        id: proc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windows = JSON.parse(this.text || "[]")
                        .filter(w => w.mapped && w.title !== "")
                        .sort((a, b) => a.focusHistoryID - b.focusHistoryID);
                } catch (e) {
                    console.warn("Windows: could not parse hyprctl clients:", e);
                }
            }
        }
    }

    Process { id: focusProc }

    // Kept warm rather than fetched on demand: `hyprctl clients -j` is a
    // round-trip, and the switcher needs the list the instant SUPER+TAB lands --
    // reading it straight after calling reload() gets the *previous* answer.
    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.reload()
    }
}
