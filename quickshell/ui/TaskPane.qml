import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.ui.components

Section {
    id: root

    title: "Tasks"
    icon: "󰄲"
    trailing: {
        const parts = [];
        if (Tasks.overdue.length > 0)
            parts.push(`${Tasks.overdue.length} overdue`);
        if (Tasks.dueSoon.length > 0)
            parts.push(`${Tasks.dueSoon.length} due`);
        parts.push(`${Tasks.tasks.length} pending`);
        return parts.join(" · ");
    }

    // Grouped by tag (this setup sets no project — see Tasks.groups).
    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        ColumnLayout {
            width: root.width
            spacing: 8

            Repeater {
                model: Tasks.groups

                ColumnLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: modelData.name
                        color: Theme.overlay1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                    }

                    Repeater {
                        model: modelData.tasks

                        ListRow {
                            id: taskRow

                            required property var modelData

                            readonly property bool isActive: modelData.uuid === Tasks.activeUuid
                            readonly property date dueDate: Tasks.parseDate(modelData.due) || new Date(0)
                            readonly property bool isOverdue: !!modelData.due && dueDate.getTime() < Date.now()

                            Layout.fillWidth: true
                            highlight: isActive

                            // Left-click toggles tracking, right-click completes:
                            // done is the destructive one, so it does not sit
                            // under the button you hit by reflex.
                            onClicked: isActive ? Tasks.stop(modelData.uuid) : Tasks.start(modelData.uuid)
                            onRightClicked: Tasks.done(modelData.uuid)

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                Text {
                                    text: taskRow.isActive ? "" : ""
                                    color: taskRow.isActive ? Theme.green : Theme.overlay0
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: taskRow.modelData.description
                                    color: taskRow.isActive ? Theme.text : Theme.subtext1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: !!taskRow.modelData.due
                                    text: Tasks.relativeDue(taskRow.modelData)
                                    color: taskRow.isOverdue ? Theme.peach : Theme.overlay1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                Text {
                                    text: ""
                                    color: taskRow.hovered ? Theme.green : "transparent"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: Tasks.tasks.length === 0
                text: "nothing pending"
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Theme.rowHeight
        radius: Theme.radius
        color: Theme.rowBg
        border.width: addInput.activeFocus ? 1 : 0
        border.color: Theme.primary

        TextInput {
            id: addInput

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
                Tasks.add(text);
                text = "";
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: addInput.text === "" && !addInput.activeFocus
                text: "add task…  (+tag due:tomorrow)"
                color: Theme.overlay0
                font: addInput.font
            }
        }
    }
}
