import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui.components

Section {
    id: root

    title: "Time"
    icon: ""
    trailing: Timew.todaySeconds > 0 ? `${Timew.formatDuration(Timew.todaySeconds)} today` : ""

    // Tracking: the running tag, a live elapsed clock, and stop.
    ListRow {
        Layout.fillWidth: true
        visible: Timew.tracking
        highlight: true

        onClicked: Timew.stop()

        RowLayout {
            anchors.fill: parent
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: 4
                color: Theme.secondary

                SequentialAnimation on opacity {
                    running: Timew.tracking
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                }
            }

            Text {
                Layout.fillWidth: true
                text: Timew.activeTag
                color: Theme.lightPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                text: Timew.formatDuration(Timew.activeSeconds)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Text {
                text: ""
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }

    // Not tracking: type a tag, or pick one already used today. This is the
    // state the pane sits in most of the time on this machine.
    RowLayout {
        Layout.fillWidth: true
        visible: !Timew.tracking
        spacing: 6

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.rowHeight
            radius: Theme.radius
            color: Theme.rowBg
            border.width: tagInput.activeFocus ? 1 : 0
            border.color: Theme.primary

            TextInput {
                id: tagInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                selectionColor: Theme.primary
                clip: true

                onAccepted: {
                    Timew.start(text);
                    text = "";
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: tagInput.text === "" && !tagInput.activeFocus
                    text: "start tracking…"
                    color: Theme.overlay0
                    font: tagInput.font
                }
            }
        }
    }

    // Today's tags, click to start or switch.
    Flow {
        id: chips

        Layout.fillWidth: true
        spacing: 6
        visible: suggestions.length > 0

        readonly property var suggestions: {
            const seen = {};
            const out = [];
            for (const t of Timew.todayTotals) {
                if (t.tag === Timew.activeTag)
                    continue;
                seen[t.tag] = true;
                out.push(t.tag);
            }
            // Tags carried by pending tasks make good tracking tags too.
            for (const g of Tasks.groups) {
                if (g.name === "untagged" || seen[g.name] || g.name === Timew.activeTag)
                    continue;
                seen[g.name] = true;
                out.push(g.name);
            }
            return out;
        }

        Repeater {
            model: chips.suggestions

            Rectangle {
                required property string modelData

                implicitWidth: label.implicitWidth + 16
                implicitHeight: 24
                radius: 12
                color: chipMouse.containsMouse ? Theme.rowHover : Theme.rowBg

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Timew.switchTo(modelData)
                }
            }
        }
    }
}
