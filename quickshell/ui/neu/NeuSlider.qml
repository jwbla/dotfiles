import QtQuick
import qs

// .neu-progress with a grab handle: an inset track (the well) and a raised thumb.
Item {
    id: root

    property real value: 0
    signal moved(real v)

    implicitHeight: 20
    implicitWidth: 120

    NeuSurface {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 10
        mode: "inset"
        tier: "s"
        radius: height / 2
        surface: Theme.neuBgComponent

        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            anchors.margins: 2
            width: Math.max(0, (parent.width - 4) * Math.max(0, Math.min(1, root.value)))
            radius: height / 2
            color: Theme.neuAccentText
            Behavior on width { NumberAnimation { duration: Theme.fastMs } }
        }
    }

    NeuSurface {
        id: thumb
        width: 16
        height: 16
        anchors.verticalCenter: parent.verticalCenter
        x: (root.width - width) * Math.max(0, Math.min(1, root.value))
        mode: "raised"
        tier: "xs"
        radius: width / 2
        surface: Theme.neuHoverHighlight
        Behavior on x { NumberAnimation { duration: Theme.fastMs } }
    }

    MouseArea {
        anchors.fill: parent
        onPositionChanged: (m) => { if (pressed) root.moved(Math.max(0, Math.min(1, m.x / width))); }
        onPressed: (m) => root.moved(Math.max(0, Math.min(1, m.x / width)))
    }
}
