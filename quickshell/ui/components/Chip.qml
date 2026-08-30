import QtQuick
import QtQuick.Layouts
import qs
import qs.ui.neu

// Clickable pill: optional status dot (or spinner in its place), optional
// nerd-font icon, label. The glance panel's repo, service and dashboard
// strips are made of these.
//
// Wears .neu-chip's inset well, so a chip reads as a recessed readout rather
// than a floating tag; hovering a clickable one raises it.
NeuSurface {
    id: root

    property string label: ""
    property string icon: ""
    property color iconColor: Theme.neuAccentLight

    property bool dotVisible: false
    property color dotColor: Theme.neuTextDim
    // Slow blink for "in progress" states.
    property bool dotPulse: false
    // Replaces the dot while the backing feed is being re-checked.
    property bool spinning: false

    property bool clickable: true
    property bool dim: false

    readonly property bool hovered: mouse.containsMouse

    signal clicked()
    signal rightClicked()

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 26

    mode: mouse.containsMouse && clickable ? "raised" : "inset"
    tier: "s"
    radius: 13
    surface: mouse.containsMouse && clickable ? Theme.neuHoverHighlight
                                              : Theme.neuBgComponent
    opacity: dim ? 0.55 : 1

    onDotPulseChanged: {
        if (!dotPulse)
            dot.opacity = 1;
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Item {
            visible: root.dotVisible
            Layout.preferredWidth: 10
            Layout.preferredHeight: 14

            Rectangle {
                id: dot
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: root.dotColor
                visible: !root.spinning

                SequentialAnimation on opacity {
                    running: root.dotPulse && root.visible && !root.spinning
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                }
            }

            Spinner {
                anchors.centerIn: parent
                visible: root.spinning
                color: Theme.neuAccentLight
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.iconColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            text: root.label
            color: root.hovered && root.clickable ? Theme.neuText : Theme.neuTextMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (event) {
            if (!root.clickable)
                return;
            if (event.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }
}
