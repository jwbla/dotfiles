import QtQuick
import qs

// .neu-chip -- an inset label:value micro-readout. The colon is drawn by the
// component, not passed in, exactly as `.neu-chip-label::after { content: ':' }`
// does in the web kit.
NeuSurface {
    id: root

    property string label: ""
    property string value: ""
    property color valueColor: Theme.neuText
    property string icon: ""
    property color iconColor: Theme.neuAccentText
    property bool dim: false

    mode: "inset"
    tier: "s"
    radius: Theme.radiusL
    surface: Theme.neuBgComponent
    opacity: dim ? 0.55 : 1

    implicitWidth: row.implicitWidth + Theme.sizeM * 2
    implicitHeight: Math.max(26, row.implicitHeight + Theme.sizeXs * 2)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.sizeXs

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: root.iconColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontS
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label + ":"
            color: Theme.neuTextMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontS
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.value !== ""
            text: root.value
            color: root.valueColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontS
            font.weight: Theme.weightSemibold
        }
    }
}
