import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui.components

// Open PRs across the Gitea org. The status icon is the head commit's combined
// CI state; it turns into a spinner whenever the feed is re-checking so a
// stale tick never looks current. Left-click opens the PR, right-click jumps
// to the first failing job (or the repo's Actions page).
Section {
    id: root

    signal activated()

    readonly property var feed: Rgtv.prs

    title: "Pull requests"
    icon: "\uf126"
    trailing: {
        if (feed.error !== "" && !feed.loaded)
            return "unreachable";
        const n = feed.data.length;
        const parts = [`${n} open`];
        if (Rgtv.prsFailing > 0)
            parts.push(`${Rgtv.prsFailing} failing`);
        if (Rgtv.prsPending > 0)
            parts.push(`${Rgtv.prsPending} running`);
        return parts.join(" · ");
    }

    Repeater {
        model: feed.data

        ListRow {
            id: prRow

            required property var modelData

            readonly property var ci: modelData.ci
            readonly property bool checking: root.feed.loading
            readonly property bool ciRunning: ci.state === "pending"
            readonly property bool ciFailing: Rgtv.isFailing(ci.state)

            readonly property string ciIcon: ci.state === "success" ? "\uf058"
                                           : ciFailing ? "\uf057"
                                           : ci.state === "none" ? "\uf10c"
                                           : "\uf059"
            readonly property color ciColor: ci.state === "success" ? Theme.green
                                           : ciFailing ? Theme.red
                                           : Theme.overlay0

            readonly property string meta: {
                const p = modelData;
                const parts = [p.author];
                if (p.head_ref)
                    parts.push(`${p.head_ref} → ${p.base_ref}`);
                if (p.changed_files > 0)
                    parts.push(`+${p.additions} −${p.deletions}`);
                if (ciRunning)
                    parts.push(`${ci.success}/${ci.total} checks`);
                else if (ciFailing)
                    parts.push(`${ci.failure}/${ci.total} failing`);
                else if (ci.total > 0)
                    parts.push(`${ci.total} checks`);
                if (p.comments > 0)
                    parts.push(`${p.comments} comments`);
                return parts.join(" · ");
            }

            Layout.fillWidth: true
            implicitHeight: 50
            highlight: ciFailing

            onClicked: {
                Rgtv.open(modelData.url);
                root.activated();
            }
            onRightClicked: {
                Rgtv.open(ci.failing_url || modelData.actions_url);
                root.activated();
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18

                        Spinner {
                            anchors.centerIn: parent
                            visible: prRow.checking || prRow.ciRunning
                            color: prRow.checking ? Theme.lightPrimary : Theme.yellow
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !prRow.checking && !prRow.ciRunning
                            text: prRow.ciIcon
                            color: prRow.ciColor
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    Text {
                        text: `${prRow.modelData.repo}#${prRow.modelData.number}`
                        color: Theme.lightPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: prRow.modelData.title
                        color: prRow.modelData.draft ? Theme.subtext0 : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }

                    Text {
                        text: Rgtv.ago(prRow.modelData.updated_at)
                        color: Theme.overlay1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 26
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: prRow.meta
                        color: Theme.overlay1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    // Flags that deserve their own colour rather than a spot
                    // in the grey meta line.
                    Text {
                        visible: prRow.modelData.draft
                        text: "draft"
                        color: Theme.overlay1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.italic: true
                    }

                    Text {
                        visible: prRow.modelData.mergeable === false
                        text: "\uf071 conflicts"
                        color: Theme.peach
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Text {
                        visible: prRow.modelData.reviews.changes.length > 0
                        text: `\uf00d ${prRow.modelData.reviews.changes.join(", ")}`
                        color: Theme.red
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Text {
                        visible: prRow.modelData.reviews.approved.length > 0
                        text: `\uf00c ${prRow.modelData.reviews.approved.join(", ")}`
                        color: Theme.green
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Text {
                        visible: prRow.modelData.reviews.requested.length > 0
                        text: `\uf06e ${prRow.modelData.reviews.requested.join(", ")}`
                        color: Theme.sapphire
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        visible: feed.loaded && feed.data.length === 0 && feed.error === ""
        text: "no open pull requests"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
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
