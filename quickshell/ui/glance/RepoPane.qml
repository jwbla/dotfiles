import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui.components

// Is master green? One chip per org repo, coloured by the default branch's
// combined CI state; failing repos are sorted first by the feed. Left-click
// opens the repo, right-click its Actions page.
Section {
    id: root

    signal activated()

    readonly property var feed: Rgtv.repos

    title: "Repos"
    icon: "\uf1d3"
    trailing: {
        if (feed.error !== "" && !feed.loaded)
            return "unreachable";
        const green = feed.data.filter(r => r.ci.state === "success").length;
        const running = feed.data.filter(r => r.ci.state === "pending").length;
        const parts = [`${green} green`];
        if (Rgtv.reposFailing > 0)
            parts.push(`${Rgtv.reposFailing} red`);
        if (running > 0)
            parts.push(`${running} running`);
        return parts.join(" · ");
    }

    function stateColor(state) {
        if (state === "success")
            return Theme.green;
        if (Rgtv.isFailing(state))
            return Theme.red;
        if (state === "pending")
            return Theme.yellow;
        return Theme.overlay0;
    }

    Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: feed.data

            Chip {
                required property var modelData

                label: modelData.name
                dotVisible: true
                dotColor: root.stateColor(modelData.ci.state)
                dotPulse: modelData.ci.state === "pending"
                spinning: root.feed.loading
                dim: modelData.ci.state === "none"

                onClicked: {
                    Rgtv.open(modelData.url);
                    root.activated();
                }
                onRightClicked: {
                    Rgtv.open(modelData.actions_url);
                    root.activated();
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        visible: !feed.loaded && feed.loading
        text: "checking gitea…"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
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
