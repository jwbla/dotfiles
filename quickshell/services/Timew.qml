pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Timewarrior 1.9.
//
// `timew get` aborts the whole invocation if any one DOM reference is invalid,
// and dom.active.tag.1 IS invalid whenever nothing is tracked — so the active
// interval is read from `timew export :today` instead of a DOM query. An
// interval with no `end` is the running one.
Singleton {
    id: root

    // Today's intervals, as exported.
    property var intervals: []

    // Set by the panel so the refresh poll only runs while it is on screen.
    property bool live: false

    // Ticks once a second while tracking so the elapsed label updates without
    // shelling out to timew every second.
    property date now: new Date()

    readonly property var activeInterval: {
        for (const i of intervals)
            if (!i.end)
                return i;
        return null;
    }

    readonly property bool tracking: activeInterval !== null

    readonly property string activeTag: {
        const a = activeInterval;
        return a && a.tags && a.tags.length > 0 ? a.tags[0] : "";
    }

    readonly property int activeSeconds: {
        const a = activeInterval;
        if (!a)
            return 0;
        const start = parseDate(a.start);
        if (!start)
            return 0;
        return Math.max(0, Math.floor((now.getTime() - start.getTime()) / 1000));
    }

    // [{ tag, seconds }] for today, busiest first, including the running one.
    readonly property var todayTotals: {
        const totals = {};
        for (const i of intervals) {
            const start = parseDate(i.start);
            if (!start)
                continue;
            const end = i.end ? parseDate(i.end) : now;
            if (!end)
                continue;

            const secs = Math.max(0, Math.floor((end.getTime() - start.getTime()) / 1000));
            const tag = i.tags && i.tags.length > 0 ? i.tags[0] : "untagged";
            totals[tag] = (totals[tag] || 0) + secs;
        }

        const out = [];
        for (const tag of Object.keys(totals))
            out.push({
                tag: tag,
                seconds: totals[tag]
            });
        out.sort((a, b) => b.seconds - a.seconds);
        return out;
    }

    readonly property int todaySeconds: todayTotals.reduce((acc, t) => acc + t.seconds, 0)

    // Timewarrior emits the same ISO 8601 basic form as taskwarrior.
    function parseDate(s) {
        if (!s)
            return null;
        const m = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/.exec(s);
        if (!m)
            return null;
        return new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]));
    }

    function formatDuration(secs) {
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const s = secs % 60;
        if (h > 0)
            return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
        return `${m}:${String(s).padStart(2, "0")}`;
    }

    function reload() {
        listProc.running = true;
    }

    function start(tag) {
        const t = (tag || "").trim();
        if (t === "")
            return;
        run(["timew", "start"].concat(t.split(/\s+/)));
    }

    function stop() {
        run(["timew", "stop"]);
    }

    function switchTo(tag) {
        // `timew start` on an already-running interval closes it and opens the
        // new one, so no explicit stop is needed.
        start(tag);
    }

    function run(cmd) {
        if (mutateProc.running)
            return;
        mutateProc.command = cmd;
        mutateProc.running = true;
    }

    Process {
        id: listProc
        command: ["timew", "export", ":today"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.intervals = JSON.parse(this.text || "[]");
                } catch (e) {
                    console.warn("Timew: could not parse timew export:", e);
                    root.intervals = [];
                }
            }
        }
    }

    Process {
        id: mutateProc
        onExited: function (code) {
            if (code !== 0)
                console.warn("Timew: command failed with", code, JSON.stringify(command));
            root.reload();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.live && root.tracking
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
}
