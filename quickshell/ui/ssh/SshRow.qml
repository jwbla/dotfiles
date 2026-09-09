import QtQuick
import QtQuick.Layouts
import qs
import qs.ui.neu

// One entry in the phone book: the label you think of it by, and the address
// ssh will actually dial, dimmer, beneath it.
NeuSurface {
    id: root

    required property var entry
    property bool selected: false

    signal activated()

    mode: "raised"
    tier: (hover.hovered || selected) ? "s" : "xs"
    radius: Theme.radiusM
    surface: (hover.hovered || selected) ? Theme.neuHoverHighlight : Theme.neuBgComponent

    implicitHeight: body.implicitHeight + Theme.sizeM * 2

    RowLayout {
        id: body
        anchors.fill: parent
        anchors.leftMargin: Theme.sizeM
        anchors.rightMargin: Theme.sizeM
        anchors.topMargin: Theme.sizeM
        anchors.bottomMargin: Theme.sizeM
        spacing: Theme.sizeM

        Text {
            text: Icons.terminal
            color: (hover.hovered || root.selected) ? Theme.neuAccentText : Theme.neuTextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontM
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.entry.name
                color: Theme.neuText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontM
                font.weight: Theme.weightSemibold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                // The address, plus the port when the phone book overrides one.
                text: root.entry.detail
                    + (root.entry.port ? ":" + root.entry.port : "")
                color: Theme.neuTextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                elide: Text.ElideRight
            }
        }

        // Where the entry came from, for when a name resolves to something
        // surprising: the JSON shadowing an ssh_config block is the whole point
        // of the merge, and this is where you see it happened.
        Text {
            visible: root.entry.source === "json"
            text: "★"
            color: Theme.neuAccentText
            opacity: 0.55
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontXs
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler { onTapped: root.activated() }
}
