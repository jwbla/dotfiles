pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Taskwarrior 3.x (TaskChampion sqlite backend).
//
// Two things the CLI is fussy about, both learned the hard way:
//   - the filter must come BEFORE the subcommand and be separate argv tokens;
//     `task export '<whole filter>'` silently degrades to "no such report".
//   - tasks are addressed by uuid, never id, because ids renumber.
Singleton {
    id: root

    // Raw pending tasks, newest export.
    property var tasks: []
    property bool loading: false

    // Set by the panel so the refresh poll only runs while it is on screen.
    property bool live: false

    readonly property var overdue: tasks.filter(t => {
        const d = parseDate(t.due);
        return d && d.getTime() < Date.now();
    })

    readonly property var dueSoon: tasks.filter(t => {
        const d = parseDate(t.due);
        if (!d)
            return false;
        const ms = d.getTime() - Date.now();
        return ms >= 0 && ms < 24 * 3600 * 1000;
    })

    // The task carrying `start` is the one `task start` marked active.
    readonly property string activeUuid: {
        for (const t of tasks)
            if (t.start)
                return t.uuid;
        return "";
    }

    // No task here sets `project`; this setup groups by tag. Honour project
    // first anyway so the pane keeps working if that ever changes.
    readonly property var groups: {
        const buckets = {};
        for (const t of tasks) {
            const key = t.project || (t.tags && t.tags.length > 0 ? t.tags[0] : "untagged");
            if (!buckets[key])
                buckets[key] = [];
            buckets[key].push(t);
        }

        const out = [];
        for (const key of Object.keys(buckets).sort()) {
            const items = buckets[key].slice().sort(compareTasks);
            out.push({
                name: key,
                tasks: items
            });
        }
        return out;
    }

    // Taskwarrior emits ISO 8601 basic form: 20260522T234545Z
    function parseDate(s) {
        if (!s)
            return null;
        const m = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/.exec(s);
        if (!m)
            return null;
        return new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]));
    }

    // Overdue first, then soonest due, then most urgent, then description.
    function compareTasks(a, b) {
        const da = parseDate(a.due);
        const db = parseDate(b.due);
        if (da && db && da.getTime() !== db.getTime())
            return da.getTime() - db.getTime();
        if (da && !db)
            return -1;
        if (!da && db)
            return 1;
        if ((b.urgency || 0) !== (a.urgency || 0))
            return (b.urgency || 0) - (a.urgency || 0);
        return a.description.localeCompare(b.description);
    }

    function relativeDue(t) {
        const d = parseDate(t.due);
        if (!d)
            return "";

        let secs = Math.round((d.getTime() - Date.now()) / 1000);
        const overdue = secs < 0;
        secs = Math.abs(secs);

        let out;
        if (secs < 3600)
            out = `${Math.max(1, Math.round(secs / 60))}m`;
        else if (secs < 86400)
            out = `${Math.round(secs / 3600)}h`;
        else
            out = `${Math.round(secs / 86400)}d`;

        return overdue ? `${out} ago` : `in ${out}`;
    }

    function reload() {
        listProc.running = true;
    }

    function done(uuid) {
        enqueue(["task", "rc.confirmation=off", "rc.verbose=nothing", uuid, "done"]);
    }

    function start(uuid) {
        enqueue(["task", "rc.confirmation=off", "rc.verbose=nothing", uuid, "start"]);
    }

    function stop(uuid) {
        enqueue(["task", "rc.confirmation=off", "rc.verbose=nothing", uuid, "stop"]);
    }

    function add(description) {
        const words = description.trim().split(/\s+/).filter(w => w !== "");
        if (words.length === 0)
            return;
        // Split on whitespace so inline attributes (due:tomorrow, +tag) parse
        // the way they do in a shell.
        enqueue(["task", "rc.confirmation=off", "rc.verbose=nothing", "add"].concat(words));
    }

    // Mutations are serialised: reassigning a running Process's command drops
    // the in-flight one.
    property var _queue: []

    function enqueue(cmd) {
        _queue = _queue.concat([cmd]);
        _pump();
    }

    function _pump() {
        if (mutateProc.running || _queue.length === 0)
            return;
        const next = _queue[0];
        _queue = _queue.slice(1);
        mutateProc.command = next;
        mutateProc.running = true;
    }

    Process {
        id: listProc
        command: ["task", "rc.verbose=nothing", "rc.json.array=on", "status:pending", "export"]
        onStarted: root.loading = true
        onExited: root.loading = false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.tasks = JSON.parse(this.text || "[]");
                } catch (e) {
                    console.warn("Tasks: could not parse task export:", e);
                    root.tasks = [];
                }
            }
        }
    }

    Process {
        id: mutateProc
        onExited: function (code) {
            if (code !== 0)
                console.warn("Tasks: command failed with", code, JSON.stringify(command));
            root._pump();
            root.reload();
        }
    }

    // Deliberately NOT a FileView watch on ~/.task/taskchampion.sqlite3:
    // FileView loads the file it watches, and that is an 880KB binary rewritten
    // on every WAL flush. Correctness comes from reloading after our own
    // mutations; this slow poll only exists to notice edits made in a terminal
    // while the panel happens to be open.
    Timer {
        interval: 30000
        repeat: true
        running: root.live
        onTriggered: root.reload()
    }
}
