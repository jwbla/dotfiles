import QtQuick
import qs

// Rotating nerd-font ring: stands in for a status icon while its feed is
// mid-check, and (in yellow) for CI that is itself still running.
Text {
    id: root

    property bool running: true

    text: "\uf1ce"
    color: Theme.lightPrimary
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    RotationAnimation on rotation {
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: root.running && root.visible
    }
}
