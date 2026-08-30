import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui.components

// Grafana dashboards, straight from its anonymous /api/search. Fetched once
// per panel open rather than on the 30s poll: the list only changes when
// rgtv-infra ships a new dashboard.
Section {
    id: root

    signal activated()

    readonly property var feed: Rgtv.dashboards

    title: "Dashboards"
    icon: "\uf080"
    trailing: feed.error !== "" && !feed.loaded ? "unreachable" : (feed.loaded ? `${feed.data.length} in grafana` : "")

    Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: feed.data

            Chip {
                required property var modelData

                // "Gitea overview" → "Gitea"; the strip is all overviews.
                label: modelData.title.replace(/ overview$/i, "")
                icon: "\uf080"

                onClicked: {
                    Rgtv.open(modelData.url);
                    root.activated();
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        visible: !feed.loaded && feed.loading
        text: "asking grafana…"
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
