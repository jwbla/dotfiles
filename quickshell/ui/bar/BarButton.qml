import QtQuick
import qs
import qs.ui.neu

// A bar-height hit target. Bare at rest -- the bar is already a surface, so
// giving every module its own relief would turn the row into gravel. Relief
// appears only on hover, which is where "pressable" needs to be legible.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property color tint: Theme.neuTextMuted
    property bool active: false

    signal activated()
    signal secondaryActivated()
    signal scrolled(int delta)

    implicitWidth: Math.max(24, content.implicitWidth + Theme.sizeM)
    implicitHeight: Theme.barHeight - Theme.sizeS * 2

    NeuSurface {
        anchors.fill: parent
        visible: hover.hovered || root.active
        mode: root.active ? "inset" : "raised"
        tier: "xs"
        radius: Theme.radiusS
        surface: Theme.neuHoverHighlight
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.sizeXs

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: root.active ? Theme.neuAccentText : root.tint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontL
            Behavior on color { ColorAnimation { duration: Theme.fastMs } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            color: root.active ? Theme.neuAccentText : root.tint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontM
            Behavior on color { ColorAnimation { duration: Theme.fastMs } }
        }
    }

    HoverHandler { id: hover }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (e) => e.button === Qt.RightButton ? root.secondaryActivated()
                                                     : root.activated()
    }

    WheelHandler {
        onWheel: (e) => root.scrolled(e.angleDelta.y > 0 ? 1 : -1)
    }
}
