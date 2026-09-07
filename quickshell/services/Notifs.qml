pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification history store.
//
// NotificationLayer is the daemon and the toast; this is the part that remembers.
// A toast's whole life is 6-8 seconds and then `dismiss()` drops it out of
// `trackedNotifications` for good -- which is fine for the popup and useless for
// "what did I miss while the screen was locked". Every notification is copied
// into a plain-JS record here on arrival, and that record outlives both the
// toast and the shell.
//
// This singleton is also the open/closed state for the center itself, so the bar
// module, the IPC handler and the panel can all talk to it without any of them
// knowing about each other -- nothing new has to be threaded through shell.qml.
Singleton {
    id: root

    // ---- store ---------------------------------------------------------

    // Newest first. Entries are plain objects, not Notification handles: the
    // handles are destroyed when the notification closes.
    property var entries: []

    // Toasts stay silent while this is on, but history still records -- the
    // point of do-not-disturb is to defer the interruption, not to lose it.
    property bool dnd: false

    // True once the file on disk has been read. Nothing is written before then,
    // so a slow first load can never truncate an existing history.
    property bool loaded: false

    readonly property int count: entries.length
    readonly property int unread: entries.filter(e => !e.read).length
    readonly property bool unreadCritical:
        entries.some(e => !e.read && e.urgency === NotificationUrgency.Critical)

    // How many notifications are kept. 200 is roughly a fortnight of this
    // desktop's traffic and lands around 40KB on disk -- small enough to rewrite
    // whole on every change, which is what makes remove/clear/trim trivial.
    readonly property int cap: 200

    // Per-field limits so one pathological app cannot grow the file without
    // bound. A body longer than this was never readable in a toast either.
    readonly property int bodyCap: 2000
    readonly property int summaryCap: 300

    // Identical (app, summary, body) arriving inside this window bumps a count
    // on the existing entry instead of appending. This is what keeps a progress
    // notification that replaces itself thirty times from becoming thirty rows.
    readonly property int coalesceMs: 60000

    // ---- ingest --------------------------------------------------------

    /**
     * Copy a live Notification into history. Called from the server's
     * onNotification, before the toast ever appears.
     */
    function record(n) {
        if (!n)
            return;

        // Transient notifications are the volume/brightness OSDs and friends:
        // they are a HUD, not a message, and their whole contract is that they
        // are not worth keeping. Honour the hint rather than filtering by app.
        if (n.transient)
            return;

        const now = Date.now();
        const appName = String(n.appName || "").slice(0, summaryCap);
        const summary = String(n.summary || "").slice(0, summaryCap);
        const body = String(n.body || "").slice(0, bodyCap);

        const next = entries.slice();

        // Coalesce a repeat of the same message.
        const dup = next.findIndex(e => e.appName === appName && e.summary === summary
                                     && e.body === body && now - e.time < coalesceMs);
        if (dup !== -1) {
            const hit = Object.assign({}, next[dup], {
                time: now,
                count: next[dup].count + 1,
                read: false,
                urgency: n.urgency
            });
            next.splice(dup, 1);
            next.unshift(hit);
            entries = next;
            _scheduleSave();
            return;
        }

        next.unshift({
            // Unique for the model's lifetime. The server's own id is reused on
            // replacement, so it cannot be the key.
            key: `${now}-${Math.random().toString(36).slice(2, 8)}`,
            time: now,
            appName: appName,
            appIcon: String(n.appIcon || ""),
            summary: summary,
            body: body,
            urgency: n.urgency,
            read: false,
            count: 1
        });

        entries = next.slice(0, cap);
        _scheduleSave();
    }

    // ---- mutation ------------------------------------------------------

    function remove(key) {
        entries = entries.filter(e => e.key !== key);
        _save();
    }

    function clear() {
        entries = [];
        _save();
    }

    function markAllRead() {
        if (unread === 0)
            return;
        entries = entries.map(e => e.read ? e : Object.assign({}, e, { read: true }));
        _scheduleSave();
    }

    function setDnd(on) {
        if (dnd === on)
            return;
        dnd = on;
        _scheduleSave();
    }

    function toggleDnd() {
        setDnd(!dnd);
    }

    // ---- the center's open state ---------------------------------------
    //
    // Held here rather than on the panel so the bar bell and the IPC handler
    // can both reach it. Closing is what marks the backlog read, not opening:
    // mark on open and every row is already grey by the time the panel has
    // finished animating, which throws away the one cue that says which of these
    // you have not seen.

    property bool centerOpen: false

    function open() {
        centerOpen = true;
    }

    function close() {
        centerOpen = false;
        markAllRead();
    }

    function toggle() {
        if (centerOpen)
            close();
        else
            open();
    }

    // ---- relative time -------------------------------------------------

    // Ticks only while the center is open; nothing else displays a timestamp.
    property date now: new Date()

    Timer {
        interval: 30000
        repeat: true
        running: root.centerOpen
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    /** "12s" / "4m" / "3h" / "2d", matching Rgtv.ago's vocabulary. */
    function ago(ms) {
        const s = Math.max(0, Math.round((now.getTime() - ms) / 1000));
        if (s < 60)
            return `${s}s`;
        if (s < 3600)
            return `${Math.round(s / 60)}m`;
        if (s < 86400)
            return `${Math.round(s / 3600)}h`;
        return `${Math.round(s / 86400)}d`;
    }

    // ---- persistence ---------------------------------------------------
    //
    // ~/.local/state/quickshell/by-shell/commandcenter/notifications.json.
    // One JSON document rewritten whole rather than an append-only log: the cap
    // trim, per-entry dismissal and clear-all all rewrite anyway, so a log would
    // only add a compaction pass to maintain.

    readonly property string path: Quickshell.statePath("notifications.json")

    Component.onCompleted: {
        // Quickshell creates its state root lazily and FileView will not make
        // the parent itself, so a first run has nowhere to write to.
        Quickshell.execDetached(["mkdir", "-p", path.replace(/\/[^/]*$/, "")]);
        store.reload();
    }

    FileView {
        id: store

        path: root.path
        atomicWrites: true
        // A missing file is the normal first-run state, not something to log.
        printErrors: false

        onLoaded: {
            try {
                const doc = JSON.parse(text() || "{}");
                if (Array.isArray(doc.entries))
                    root.entries = doc.entries.slice(0, root.cap);
                root.dnd = !!doc.dnd;
            } catch (e) {
                console.warn("Notifs: unreadable history, starting empty:", e);
            }
            root.loaded = true;
        }

        onLoadFailed: {
            // No file yet. Empty history is the right answer.
            root.loaded = true;
        }
    }

    // Coalesce bursts: a build finishing can fire several notifications in a
    // frame, and each one would otherwise be its own rewrite.
    Timer {
        id: saveDebounce
        interval: 1000
        onTriggered: root._save()
    }

    function _scheduleSave() {
        if (loaded)
            saveDebounce.restart();
    }

    function _save() {
        if (!loaded)
            return;
        saveDebounce.stop();
        store.setText(JSON.stringify({
            version: 1,
            dnd: dnd,
            entries: entries
        }));
    }
}
