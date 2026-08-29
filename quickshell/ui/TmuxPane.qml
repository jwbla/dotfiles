import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui.components

Section {
    id: root

    signal activated()

    title: "tmux"
    icon: ""
    trailing: `${Tmux.projects.filter(p => p.running).length}/${Tmux.projects.length}`

    Repeater {
        model: Tmux.projects

        ListRow {
            required property var modelData

            Layout.fillWidth: true
            highlight: modelData.running

            onClicked: {
                Tmux.attach(modelData.name);
                root.activated();
            }

            RowLayout {
                anchors.fill: parent
                spacing: 8

                Text {
                    text: modelData.running ? "●" : "○"
                    color: modelData.running ? Theme.green : Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.name
                    color: modelData.running ? Theme.text : Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: Tmux.projects.length === 0
        text: "no tms projects"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }
}
