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

    // Every pack sysfs exposes: [{ name, pct, status }]. The bar draws one icon
    // each; `battery*` below is the aggregate across all of them, weighted by
    // capacity where sysfs reports energy/charge units.
    readonly property var batteries: (data.bats || [])

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

    // What the desktop should be showing: the level we have asked for while a
    // change is in flight, and the polled truth the rest of the time. Without
    // the optimistic half, a scroll only moves the number when the 3s poll
    // comes back, and the notches in between all compute from the same stale
    // base -- a flick of the wheel used to move the volume 5% in total.
    readonly property int volumePct: volWanted >= 0 ? volWanted
        : ((data.vol && data.vol.pct !== null) ? data.vol.pct : -1)
    readonly property bool muted: !!(data.vol && data.vol.muted)

    property int volWanted: -1   // level we want; -1 once the poll has caught up
    property int volLast: -1     // level pactl was last told, to spot a no-op

    readonly property real cpu: data.cpu || 0
    readonly property real mem: data.mem || 0
    readonly property real disk: data.disk || 0

    // Load average over the 1-minute window, divided by core count: 1.0 means
    // every core has a runnable process queued behind the one it is running.
    // cpu% cannot say this -- it pins at 1.0 and stops distinguishing "busy"
    // from "buried", which is the distinction that matters when CI is building
    // on this box and the desktop starts feeling wrong.
    readonly property real loadNorm: (data.load && data.load.norm) || 0
    readonly property real loadAvg1: (data.load && data.load.avg1) || 0
    readonly property int cores: (data.load && data.load.cores) || 1

    function reload() {
        if (!proc.running)
            proc.running = true;
    }

    function setVolume(pct) {
        volWanted = Math.round(Math.max(0, Math.min(100, pct)));
        flushVolume();
    }

    /** Relative move, for the wheel. Steps from the level we asked for last. */
    function nudgeVolume(delta) {
        setVolume((volumePct >= 0 ? volumePct : 0) + delta);
    }

    // One pactl per change, and Process refuses a new command while the last
    // one is still running -- so a burst of scroll events used to land its
    // first notch and silently drop the rest. Coalesce instead: hold the level
    // we want, write it when the pipe is free, and write it once more if it
    // moved while pactl was busy.
    function flushVolume() {
        if (vol.running || volWanted < 0 || volWanted === volLast)
            return;
        volLast = volWanted;
        vol.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", volWanted + "%"];
        vol.running = true;
    }

    function toggleMute() {
        mute.command = ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"];
        mute.running = true;
    }

    function setMuted(on) {
        mute.command = ["pactl", "set-sink-mute", "@DEFAULT_SINK@", on ? "1" : "0"];
        mute.running = true;
    }

    Process {
        id: proc
        command: ["neu_sysinfo.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.data = JSON.parse(this.text || "{}");
                    root.ready = true;
                    // The write landed and this poll has seen it: hand the
                    // number back to pactl, so a change made anywhere else --
                    // a media key, pavucontrol -- still shows up here.
                    if (!vol.running && root.volWanted === root.volLast) {
                        root.volWanted = -1;
                        root.volLast = -1;
                    }
                } catch (e) {
                    console.warn("Sys: bad neu_sysinfo.sh output:", e);
                }
            }
        }
    }

    // Volume and mute keep separate pipes: a wheel flick and a click on the
    // same module must not cancel one another out.
    Process {
        id: vol
        onExited: {
            root.flushVolume();   // no-op unless the level moved while we wrote
            root.reload();
        }
    }

    Process {
        id: mute
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
