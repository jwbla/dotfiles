import QtQuick
import QtQuick.Layouts
import qs

// Collapsible titled block. The header carries the pink->purple accent bar so
// the three panes read as one panel rather than three stacked widgets.
ColumnLayout {
    id: root

    property string title: ""
    property string icon: ""
    property string trailing: ""
    property bool collapsed: false

    default property alias content: body.data

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 3
            Layout.preferredHeight: 18
            radius: 2
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Theme.primary }
                GradientStop { position: 1.0; color: Theme.secondary }
            }
        }

        Text {
            text: root.icon
            visible: root.icon !== ""
            color: Theme.lightPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeHeader
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeHeader
            font.bold: true
        }

        Text {
            text: root.trailing
            color: Theme.overlay1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            text: root.collapsed ? "\uf054" : "\uf078"
            color: Theme.overlay1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        // Handlers rather than a MouseArea: an anchored item inside a layout
        // is undefined behavior, and these are not items.
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.collapsed = !root.collapsed
        }
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: 3
        visible: !root.collapsed
    }
}
