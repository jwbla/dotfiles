import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui.components

// The fleet, as the homepage (home.i.realgamers.tv) lists it: grouped links
// with the homepage's own server-side health probe as the dot. Hovering a
// chip explains it in the footer line; clicking opens it.
Section {
    id: root

    signal activated()

    readonly property var feed: Rgtv.services

    // Set by whichever chip is under the mouse.
    property var hoveredService: null

    title: "Services"
    icon: "\uf233"
    trailing: {
        if (feed.error !== "" && !feed.loaded)
            return "unreachable";
        const parts = [`${Rgtv.servicesUp}/${Rgtv.servicesProbed} up`];
        if (Rgtv.servicesDown > 0)
            parts.push(`${Rgtv.servicesDown} down`);
        return parts.join(" · ");
    }

    // Nerd-font glyphs by homepage link id, group as the fallback. The
    // homepage API does not ship icons, so this is the one place they live.
    readonly property var icons: ({
        "gitea": "\uf1d3",
        "nexus": "\uf1b2",
        "buildbuddy": "\uf0ad",
        "coder": "\uf121",
        "act-runner": "\uf085",
        "dex": "\uf188",
        "ds-storybook": "\uf1fc",
        "rgtvkb-docs": "\uf02d",
        "observability": "\uf080",
        "dns-internal": "\uf0e8",
        "vault": "\uf023",
        "tch": "\uf095",
        "wg": "\uf132",
        "caddy": "\uf0ec",
        "authentik": "\uf084",
        "kz-gameserver": "\uf11b",
        "rgagent": "\uf26c",
        "rgtv-com": "\uf0ac"
    })

    readonly property var groupIcons: ({
        "Products": "\uf1b3",
        "Build & CI": "\uf0ad",
        "Trackers & Docs": "\uf02d",
        "Platform": "\uf233",
        "Comms": "\uf075",
        "Access": "\uf084"
    })

    function iconFor(s) {
        return icons[s.id] || groupIcons[s.group] || "";
    }

    function statusColor(status) {
        if (status === "up")
            return Theme.green;
        if (status === "down")
            return Theme.red;
        return Theme.overlay0;
    }

    // Homepage order within groups, groups in first-seen order.
    readonly property var groups: {
        const order = [];
        const buckets = {};
        for (const s of feed.data) {
            if (!buckets[s.group]) {
                buckets[s.group] = [];
                order.push(s.group);
            }
            buckets[s.group].push(s);
        }
        return order.map(g => ({ name: g, items: buckets[g] }));
    }

    Repeater {
        model: root.groups

        ColumnLayout {
            required property var modelData

            Layout.fillWidth: true
            spacing: 3

            Text {
                text: modelData.name
                color: Theme.overlay1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: modelData.items

                    Chip {
                        id: chip

                        required property var modelData

                        label: modelData.title
                        icon: root.iconFor(modelData)
                        dotVisible: true
                        dotColor: root.statusColor(modelData.status)
                        spinning: root.feed.loading && modelData.health_url !== ""
                        clickable: modelData.href !== ""
                        dim: modelData.status === "unknown" && modelData.href === ""

                        onHoveredChanged: {
                            if (hovered)
                                root.hoveredService = modelData;
                            else if (root.hoveredService === modelData)
                                root.hoveredService = null;
                        }

                        onClicked: {
                            Rgtv.open(modelData.href);
                            root.activated();
                        }
                    }
                }
            }
        }
    }

    // Footer: the hovered service's blurb, or the group summary at rest.
    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.topMargin: 2
        text: {
            const s = root.hoveredService;
            if (!s)
                return feed.loaded ? "hover a service for details" : (feed.loading ? "probing the fleet…" : "");
            const host = s.href.replace(/^https?:\/\//, "").replace(/\/$/, "");
            const parts = [s.status];
            if (s.description)
                parts.push(s.description);
            if (host)
                parts.push(host);
            return parts.join(" · ");
        }
        color: root.hoveredService ? Theme.subtext0 : Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        visible: feed.error !== ""
        text: feed.error
        color: Theme.red
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
    }
}
