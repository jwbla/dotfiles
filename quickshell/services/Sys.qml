pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Battery, network, volume and load for the bar.
//
// One `neu_sysinfo.sh` per tick rather than five bindings, because on this
// machine Quickshell's own services can't supply any of it: audio is PulseAudio
// (the Pipewire service sees no sink), networking is iwd + systemd-networkd (the
// Networking service finds no backend), and the UPower binding reports zero
// devices even though upowerd is running. sysfs and pactl always answer.
Singleton {
    id: root

    property var data: ({})
    property bool ready: false

    readonly property int batteryPct: (data.bat && data.bat.pct !== null) ? data.bat.pct : -1
    readonly property string batteryStatus: (data.bat && data.bat.status) || "unknown"
    readonly property bool onAc: !!(data.bat && data.bat.ac)
    readonly property bool charging: batteryStatus === "Charging"
    readonly property bool batteryPresent: batteryPct >= 0

    readonly property string netKind: (data.net && data.net.kind) || "none"
    readonly property string netName: (data.net && data.net.name) || ""
    readonly property bool netUp: !!(data.net && data.net.up)
    /** dBm -> 0..1. -30 is excellent, -85 is unusable. */
    readonly property real netQuality: {
        if (!data.net || data.net.signal === null || data.net.signal === undefined)
            return netUp ? 1 : 0;
        return Math.max(0, Math.min(1, (data.net.signal + 85) / 55));
    }

    readonly property int volumePct: (data.vol && data.vol.pct !== null) ? data.vol.pct : -1
    readonly property bool muted: !!(data.vol && data.vol.muted)

    readonly property real cpu: data.cpu || 0
    readonly property real mem: data.mem || 0
    readonly property real disk: data.disk || 0

    function reload() {
        if (!proc.running)
            proc.running = true;
    }

    function setVolume(pct) {
        mutate.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@",
                          Math.round(Math.max(0, Math.min(100, pct))) + "%"];
        mutate.running = true;
    }

    function toggleMute() {
        mutate.command = ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"];
        mutate.running = true;
    }

    Process {
        id: proc
        command: ["neu_sysinfo.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.data = JSON.parse(this.text || "{}");
                    root.ready = true;
                } catch (e) {
                    console.warn("Sys: bad neu_sysinfo.sh output:", e);
                }
            }
        }
    }

    Process {
        id: mutate
        onExited: root.reload()
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.reload()
    }
}
