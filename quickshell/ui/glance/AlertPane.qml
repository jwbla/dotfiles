import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui.components

// Firing Prometheus alerts + down scrape targets. Sits at the top because it
// is the one section whose empty state is the good news.
Section {
    id: root

    readonly property var feed: Rgtv.alerts
    readonly property var down: feed.data.targets.down

    title: "Alerts"
    icon: "\uf0f3"
    trailing: {
        if (feed.error !== "" && !feed.loaded)
            return "unreachable";
        const parts = [];
        parts.push(Rgtv.firing === 0 ? "all quiet" : `${Rgtv.firing} firing`);
        if (Rgtv.targetsDown > 0)
            parts.push(`${Rgtv.targetsDown} targets down`);
        if (feed.loaded && !feed.data.watchdog)
            parts.push("no watchdog");
        return parts.join(" · ");
    }

    // Watchdog is the always-firing dead-man alert; its absence means a quiet
    // list cannot be trusted.
    ListRow {
        Layout.fillWidth: true
        visible: feed.loaded && !feed.data.watchdog
        highlight: true
        onClicked: Rgtv.open(feed.data.url)

        RowLayout {
            anchors.fill: parent
            spacing: 8

            Text {
                text: "\uf071"
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Text {
                Layout.fillWidth: true
                text: "Watchdog missing — Prometheus → Alertmanager → ntfy chain is broken"
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }
        }
    }

    Repeater {
        model: feed.data.alerts

        ListRow {
            id: alertRow

            required property var modelData

            readonly property color sevColor: modelData.severity === "critical" ? Theme.red
                                            : modelData.severity === "warning" ? Theme.peach
                                            : Theme.overlay1

            Layout.fillWidth: true
            implicitHeight: 50

            onClicked: Rgtv.open(modelData.url)

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
                            visible: root.feed.loading
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.feed.loading
                            text: "\uf071"
                            color: alertRow.sevColor
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: alertRow.modelData.summary
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }

                    Text {
                        text: Rgtv.ago(alertRow.modelData.active_at)
                        color: Theme.overlay1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 26
                    text: {
                        const m = alertRow.modelData;
                        const parts = [m.severity, m.name];
                        if (m.service)
                            parts.push(m.service);
                        if (m.instance)
                            parts.push(m.instance);
                        return parts.join(" · ");
                    }
                    color: Theme.overlay1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }
        }
    }

    Repeater {
        model: root.down

        ListRow {
            id: targetRow

            required property var modelData

            Layout.fillWidth: true
            onClicked: Rgtv.open(root.feed.data.url.replace(/\/alerts.*$/, "/targets"))

            RowLayout {
                anchors.fill: parent
                spacing: 8

                Text {
                    text: "\uf071"
                    color: Theme.peach
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Text {
                    Layout.fillWidth: true
                    text: `${targetRow.modelData.job} scrape target down`
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }

                Text {
                    text: targetRow.modelData.instance
                    color: Theme.overlay1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    // Good news, said once.
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        visible: feed.loaded && feed.error === "" && feed.data.alerts.length === 0 && root.down.length === 0 && feed.data.watchdog
        spacing: 8

        Text {
            text: "\uf058"
            color: Theme.green
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        Text {
            Layout.fillWidth: true
            text: `nothing firing · ${feed.data.targets.total} scrape targets up`
            color: Theme.overlay0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
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
