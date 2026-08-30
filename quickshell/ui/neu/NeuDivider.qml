import QtQuick
import qs

// .neu-divider -- the engraved groove: one dark line with one light line under
// it. The same two-tone trick the web kit uses for table rows and list rules.
Item {
    id: root
    property bool vertical: false

    implicitWidth: vertical ? 2 : parent.width
    implicitHeight: vertical ? parent.height : 2

    Rectangle {
        color: Theme.neuShadowDark
        width: root.vertical ? 1 : parent.width
        height: root.vertical ? parent.height : 1
    }

    Rectangle {
        color: Theme.neuShadowLight
        opacity: 0.35
        x: root.vertical ? 1 : 0
        y: root.vertical ? 0 : 1
        width: root.vertical ? 1 : parent.width
        height: root.vertical ? parent.height : 1
    }
}
