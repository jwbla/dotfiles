import QtQuick
import qs

// Hover/press row shared by all three panes.
Rectangle {
    id: root

    property bool highlight: false
    readonly property bool hovered: mouse.containsMouse

    signal clicked()
    signal rightClicked()

    default property alias content: inner.data

    // Fixed, not derived from childrenRect: `inner` fills this item, so
    // sizing to its children's height is a binding loop. Rows needing more
    // room override implicitHeight themselves.
    implicitHeight: Theme.rowHeight
    radius: Theme.radius
    color: mouse.containsMouse ? Theme.rowHover : (highlight ? Theme.rowBg : "transparent")

    Behavior on color {
        ColorAnimation { duration: 90 }
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (event) {
            if (event.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }
}
