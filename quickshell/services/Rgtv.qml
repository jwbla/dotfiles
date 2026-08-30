pragma Singleton

import QtQuick
import Quickshell

// rgtv fleet at a glance. Every feed is one `rgtv_glance.sh <sub>` run (bin/
// in this repo, on PATH via install.sh); this singleton owns the parsed JSON,
// the per-feed loading flags, the refresh cadence and the link opener. Feeds
// are listed in the order the panel shows them.
Singleton {
    id: root

    // Set by the panel so polling only runs while it is on screen.
    property bool live: false

    // 1s tick driving the "checked 12s ago" / "since 3h" labels.
    property date now: new Date()
    property date lastChecked: new Date(0)

    readonly property Feed alerts: Feed {
        sub: "alerts"
        fallback: ({ alerts: [], watchdog: true, targets: { total: 0, down: [] }, url: "" })
    }
    readonly property Feed prs: Feed { sub: "prs" }
    readonly property Feed repos: Feed { sub: "repos" }
    readonly property Feed services: Feed { sub: "services" }
    readonly property Feed dashboards: Feed { sub: "dashboards" }

    // The dashboard list is static enough to fetch once per open; everything
    // else is status and gets re-polled.
    readonly property var statusFeeds: [alerts, prs, repos, services]
    readonly property var allFeeds: [alerts, prs, repos, services, dashboards]

    readonly property bool loading: alerts.loading || prs.loading || repos.loading || services.loading || dashboards.loading

    // Header summary inputs.
    readonly property int firing: alerts.data.alerts.length
    readonly property bool critical: alerts.data.alerts.some(a => a.severity === "critical")
    readonly property int targetsDown: alerts.data.targets.down.length
    readonly property int prsFailing: prs.data.filter(p => isFailing(p.ci.state)).length
    readonly property int prsPending: prs.data.filter(p => p.ci.state === "pending").length
    readonly property int reposFailing: repos.data.filter(r => isFailing(r.ci.state)).length
    readonly property int servicesUp: services.data.filter(s => s.status === "up").length
    readonly property int servicesDown: services.data.filter(s => s.status === "down").length
    readonly property int servicesProbed: services.data.filter(s => s.status !== "unknown").length

    function isFailing(state) {
        return state === "failure" || state === "error";
    }

    function reload() {
        for (const f of allFeeds)
            f.reload();
    }

    function refresh() {
        for (const f of statusFeeds)
            f.reload();
    }

    function open(url) {
        if (!url)
            return;
        Quickshell.execDetached(["xdg-open", url]);
    }

    // "12s" / "3m" / "5h" / "2d" for an ISO timestamp or a Date.
    function ago(when) {
        const t = when instanceof Date ? when.getTime() : Date.parse(when);
        if (isNaN(t) || t <= 0)
            return "";
        const s = Math.max(0, Math.round((now.getTime() - t) / 1000));
        if (s < 60)
            return `${s}s`;
        if (s < 3600)
            return `${Math.round(s / 60)}m`;
        if (s < 86400)
            return `${Math.round(s / 3600)}h`;
        return `${Math.round(s / 86400)}d`;
    }

    Component.onCompleted: {
        for (const f of allFeeds)
            f.finished.connect(() => root.lastChecked = new Date());
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.live
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.live
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
}
