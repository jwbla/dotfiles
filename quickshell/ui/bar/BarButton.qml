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
    /** Hover text. Set it on any module whose glyph has no label of its own. */
    property string tip: ""
    /** Smooth tint changes. Turn it OFF for a continuously animated tint: the
     *  Behavior restarts on every frame's new target and never arrives, which
     *  freezes the colour completely rather than merely smoothing it. */
    property bool tintAnimated: true
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
            // Duration, not `enabled`. Toggling a Behavior's enabled flag while
            // it is mid-transition leaves the property detached from its
            // binding -- the icon then keeps whatever colour it had when the
            // toggle happened, which is how the assistant glyph got stuck
            // accent-purple with nothing unread. A zero duration passes the
            // change straight through and the Behavior is never torn down.
            Behavior on color {
                ColorAnimation { duration: root.tintAnimated ? Theme.fastMs : 0 }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            color: root.active ? Theme.neuAccentText : root.tint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontM
            // Duration, not `enabled`. Toggling a Behavior's enabled flag while
            // it is mid-transition leaves the property detached from its
            // binding -- the icon then keeps whatever colour it had when the
            // toggle happened, which is how the assistant glyph got stuck
            // accent-purple with nothing unread. A zero duration passes the
            // change straight through and the Behavior is never torn down.
            Behavior on color {
                ColorAnimation { duration: root.tintAnimated ? Theme.fastMs : 0 }
            }
        }
    }

    HoverHandler { id: hover }

    NeuTooltip {
        target: root
        text: root.tip
        show: hover.hovered
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // tapped() passes (eventPoint, button) -- taking one argument gets the
        // QEventPoint, whose .button is undefined, so every right-click was
        // quietly firing the PRIMARY action. The bell's do-not-disturb has
        // never once been reachable.
        onTapped: (point, button) => button === Qt.RightButton
            ? root.secondaryActivated()
            : root.activated()
    }

    // MouseArea rather than WheelHandler: on this layer surface the handler
    // never fires. acceptedButtons: NoButton so it takes the wheel without
    // stealing clicks from the TapHandler above it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (w) => root.scrolled(w.angleDelta.y > 0 ? 1 : -1)
    }
}
