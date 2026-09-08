import QtQuick
import Quickshell
import qs

// The label a glyph does not have room for.
//
// The bar spends its width carefully: Shortcuts drops app names to protect the
// workspace strip, the launcher and the control centre are bare glyphs, and the
// tray shows other people's icons entirely. This is where that dropped
// information goes -- not decoration, but the second half of a label that was
// deliberately left off.
//
// WHY A WINDOW: the bar's Wayland surface is exactly Theme.barHeight tall, so
// anything drawn below it is not in the buffer -- an Item is simply clipped.
// QtQuick.Controls' ToolTip cannot help either: its default popup renders into
// that same clipped overlay, and forcing it into a window leaves Qt unable to
// resolve a layer surface's position at all (it lands in a screen corner).
// Quickshell implements xdg_popup against the layer surface itself, and
// PopupWindow is the way to reach it.
PopupWindow {
    id: root

    /** The thing being described. Its window and rect are resolved for us. */
    property Item target: null
    property string text: ""
    /** Raw hover signal from the caller; the delay is handled here. */
    property bool show: false
    /** Which side of the target it hangs off. Bottom suits a top bar. */
    property int edge: Edges.Bottom

    // The surface clips its own contents too, so the window carries a shadow's
    // worth of padding on every side. Without it a tier-"s" relief gets sliced
    // off at the edge -- the same failure as the bar clipping, one level down.
    readonly property int pad: Theme.shadowSGap

    visible: false
    color: "transparent"

    anchor.item: target
    anchor.edges: edge
    anchor.gravity: edge
    // The clock and the control centre sit at the very edge of the screen;
    // without this their tooltips would hang off it.
    anchor.adjustment: PopupAdjustment.SlideX

    implicitWidth: body.implicitWidth + pad * 2
    implicitHeight: body.implicitHeight + pad * 2

    // Hovering a bar is mostly done on the way somewhere else, so nothing
    // appears until you have stopped. Leaving is instant: a tooltip that
    // lingers after the pointer has gone reads as a bug.
    Timer {
        id: dwell
        interval: Theme.defaultMs
        onTriggered: root.visible = root.show && root.text !== ""
    }

    onShowChanged: {
        if (show && text !== "") {
            dwell.restart();
        } else {
            dwell.stop();
            visible = false;
        }
    }

    NeuSurface {
        id: body

        anchors.centerIn: parent
        implicitWidth: label.implicitWidth + Theme.sizeS * 2
        implicitHeight: label.implicitHeight + Theme.sizeXs * 2

        // One layer above BarButton's own hover relief, which is tier "xs".
        mode: "raised"
        tier: "s"
        radius: Theme.radiusS
        surface: Theme.neuBgCard

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            // Not neuTextMuted: the bar sits at muted, and this is the one
            // thing being read right now.
            color: Theme.neuText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontS
        }
    }
}
