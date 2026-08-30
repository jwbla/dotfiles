import QtQuick
import qs

// .neu-meter -- a segmented LED / VU readout in an inset well. The best system
// monitor primitive in the kit: unlit segments show a 14% tint of *their own
// zone colour*, so the green/amber/red zones stay legible even when dark.
NeuSurface {
    id: root

    property real value: 0          // 0..1
    property int segments: Theme.meterSegments
    property bool vertical: false
    property bool zoned: true
    property color tint: Theme.neuAccentText

    mode: "inset"
    tier: "l"
    radius: Theme.radiusS
    surface: Theme.neuBgComponent

    implicitWidth: vertical ? 20 : 120
    implicitHeight: vertical ? 140 : 20

    readonly property int litCount: Math.round(Math.max(0, Math.min(1, value)) * segments)

    // Top ~15% is the error zone, the 25% below it is warning, the rest is fine.
    function zoneColor(i) {
        if (!zoned)
            return tint;
        const p = i / segments;
        if (p >= 0.85) return Theme.neuErrorText;
        if (p >= 0.60) return Theme.neuWarningText;
        return Theme.neuSuccessText;
    }

    Item {
        anchors.fill: parent
        anchors.margins: 4

        Repeater {
            model: root.segments

            Rectangle {
                required property int index

                readonly property color seg: root.zoneColor(index)
                readonly property bool lit: index < root.litCount
                readonly property bool peak: index === root.litCount - 1

                radius: 2
                color: lit ? seg : Qt.rgba(seg.r, seg.g, seg.b, 0.14)
                opacity: peak ? 0.85 : 1

                width: root.vertical
                        ? parent.width
                        : (parent.width - (root.segments - 1) * 3) / root.segments
                height: root.vertical
                        ? (parent.height - (root.segments - 1) * 3) / root.segments
                        : parent.height
                x: root.vertical ? 0 : index * (width + 3)
                y: root.vertical ? parent.height - height - index * (height + 3) : 0

                Behavior on color { ColorAnimation { duration: Theme.fastMs } }
            }
        }
    }
}
