import QtQuick
import qs

// .neu-spinner -- the nerd-font spinner glyph, rotating at the DS's 0.8s.
// U+F1CE, written by codepoint: literal private-use glyphs do not survive
// being written to disk.
Text {
    id: root
    property color tint: Theme.neuAccentLight

    text: "\uf1ce"
    color: tint
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontM

    RotationAnimation on rotation {
        from: 0
        to: 360
        duration: Theme.spinnerMs
        loops: Animation.Infinite
        running: root.visible
    }
}
