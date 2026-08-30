import QtQuick
import qs
import qs.ui.neu

// Hover/press row shared by all the panes.
//
// Now speaks the shadow grammar rather than swapping a flat fill: a highlighted
// row is an inset well ("this one is selected/held"), a hovered row lifts into a
// shallow raised surface ("this one is pressable"), and an ordinary row has no
// relief at all. Same public API as before.
Item {
    id: root

    property bool highlight: false
    readonly property bool hovered: mouse.containsMouse

    signal clicked()
    signal rightClicked()

    default property alias content: inner.data

    // Fixed, not derived from childrenRect: `inner` fills this item, so sizing
    // to its children's height is a binding loop. Rows needing more room
    // override implicitHeight themselves.
    implicitHeight: Theme.rowHeight

    NeuSurface {
        anchors.fill: parent
        visible: root.highlight || root.hovered
        mode: root.highlight ? "inset" : "raised"
        tier: root.highlight ? "s" : "xxs"
        radius: Theme.radiusS
        surface: root.highlight ? Theme.neuBg : Theme.neuHoverHighlight
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.leftMargin: Theme.sizeS
        anchors.rightMargin: Theme.sizeS
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
