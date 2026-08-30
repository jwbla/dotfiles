import QtQuick
import qs

// The Control Center toggle tile. Note the inversion: an ACTIVE tile is flat and
// accent-filled (it is pressed in, holding), an inactive one is raised (it is
// pressable). Straight from the ControlCenter tile in the NeuOS story.
NeuSurface {
    id: root

    property bool active: false
    property string icon: ""
    property string label: ""

    signal toggled()

    mode: active ? "flat" : "raised"
    tier: "s"
    radius: Theme.radiusM
    surface: active ? Theme.neuAccent
                    : (hover.hovered ? Theme.neuHoverHighlight : Theme.neuBgCard)

    implicitWidth: 76
    implicitHeight: 62

    Column {
        anchors.centerIn: parent
        spacing: Theme.sizeXs

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            color: root.active ? Theme.neuAccentText : Theme.neuTextMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontXl
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: root.active ? Theme.neuAccentText : Theme.neuTextMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontXs
        }
    }

    HoverHandler { id: hover }

    TapHandler {
        onTapped: root.toggled()
    }
}
