import QtQuick
import qs

// .neu-button -- raised at rest, inset while held. Hover lifts the surface
// toward --neu-hover-highlight and *shortens* the shadow (l -> s), which is what
// reads as the button coming to meet you.
NeuSurface {
    id: root

    property string text: ""
    property string icon: ""
    property color tint: Theme.neuText
    property bool flat: false

    signal clicked()
    signal rightClicked()

    readonly property bool hovered: hover.hovered
    readonly property bool pressed: tap.pressed

    mode: pressed ? "inset" : (flat ? "flat" : "raised")
    tier: pressed ? "s" : (hovered ? "s" : "l")
    radius: Theme.radiusM
    surface: hovered && !pressed ? Theme.neuHoverHighlight : Theme.neuBgComponent
    glow: pressed ? Theme.neuAccent : "transparent"

    implicitWidth: row.implicitWidth + Theme.sizeL * 2
    implicitHeight: row.implicitHeight + Theme.sizeS * 2

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.sizeS

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: root.tint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontL
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            color: root.tint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontM
        }
    }

    HoverHandler { id: hover }

    TapHandler {
        id: tap
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (evt) => {
            if (evt.button === Qt.RightButton) root.rightClicked();
            else root.clicked();
        }
    }
}
