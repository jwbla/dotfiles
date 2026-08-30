import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.ui.neu

// NeuDock: a raised bar of app icons that magnifies under the pointer, with a
// running dot per item.
//
// Magnify curve from neu-dock.tsx: "Hovered -> 1.4, immediate neighbours -> 1.2,
// everything else -> 1." It auto-hides so it does not eat a strip of every
// workspace; a 4px reveal zone at the bottom edge brings it back.
PanelWindow {
    id: root

    property bool revealed: false

    WlrLayershell.namespace: "neu:dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors { bottom: true; left: true; right: true }
    implicitHeight: dockBody.implicitHeight + Theme.shadowXlGap * 2

    property int hovered: -1

    function toggle() { revealed = !revealed; }

    // Without a mask this transparent panel would swallow every click in the
    // bottom 80px of every workspace. Input is a 4px reveal strip while hidden,
    // and the whole panel once the dock is out.
    //
    // These are STATIC rectangles, deliberately not `item: dockBody`. Binding the
    // mask to the animating item makes the input region slide with it, so on the
    // way down it sweeps back under the pointer, re-enters, and re-reveals --
    // the dock ends up flapping. Hence also `hideDelay`: a brief exit (crossing a
    // window edge, the pointer leaving during the slide) should not re-trigger.
    mask: Region {
        x: 0
        y: root.revealed ? 0 : root.height - 4
        width: root.width
        height: root.revealed ? root.height : 4
    }

    Timer {
        id: hideDelay
        interval: 250
        onTriggered: {
            root.revealed = false;
            root.hovered = -1;
        }
    }

    function running(wmClass) {
        for (const t of Hyprland.toplevels.values) {
            const c = t.lastIpcObject ? t.lastIpcObject.class : "";
            if (c && wmClass && c.toLowerCase() === wmClass.toLowerCase())
                return true;
        }
        return false;
    }

    // A 4px strip along the very bottom that wakes the dock.
    Item {
        id: revealStrip
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 4

        HoverHandler {
            // Only arms while the dock is away, so the strip cannot fight the
            // body for the pointer.
            enabled: !root.revealed
            onHoveredChanged: if (hovered) {
                hideDelay.stop();
                root.revealed = true;
            }
        }
    }

    HoverHandler {
        id: bodyHover
        onHoveredChanged: hovered ? hideDelay.stop() : hideDelay.restart()
    }

    NeuSurface {
        id: dockBody

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.revealed ? Theme.shadowXlGap : root.height
        Behavior on y { NumberAnimation { duration: Theme.baseMs; easing.type: Easing.OutCubic } }

        implicitWidth: row.implicitWidth + Theme.sizeM * 2
        implicitHeight: row.implicitHeight + Theme.sizeS * 2

        mode: "raised"
        tier: "l"
        radius: Theme.radiusL
        surface: Theme.neuBgComponent

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.sizeS

            Repeater {
                model: DockConfig.pinned

                Item {
                    id: item
                    required property var modelData
                    required property int index

                    readonly property real magnify: {
                        if (root.hovered < 0) return 1;
                        const d = Math.abs(root.hovered - index);
                        if (d === 0) return Theme.dockMagHovered;
                        if (d === 1) return Theme.dockMagNeighbour;
                        return 1;
                    }

                    // The running dot needs a strip below the glyph, so the same
                    // strip is reserved ABOVE it. Without that the icon slot is
                    // bottom-heavy and every glyph sits low in the dock -- which
                    // is exactly what a bottom-anchored Column was doing here.
                    readonly property int dotStrip: Theme.sizeS

                    width: Theme.dockIconPx
                    height: Theme.dockIconPx + dotStrip * 2

                    Text {
                        id: glyph

                        // An explicit square slot with the glyph centred in it.
                        // A bare Text is only as tall as its line box, and a
                        // nerd glyph does not sit centred in its em -- so
                        // centring the Text is not the same as centring the icon.
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: item.dotStrip
                        width: Theme.dockIconPx
                        height: Theme.dockIconPx
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        text: item.modelData.icon
                        color: root.hovered === item.index ? Theme.neuAccentText
                                                           : Theme.neuTextMuted
                        font.family: Theme.fontFamily
                        // Derived from the slot rather than borrowed from the type
                        // scale, so the glyph fills the space it is given.
                        font.pixelSize: Math.round(Theme.dockIconPx * 0.66)

                        // Dock magnify scales from the bottom edge.
                        transformOrigin: Item.Bottom
                        scale: item.magnify
                        Behavior on scale { NumberAnimation { duration: Theme.baseMs; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Theme.fastMs } }
                    }

                    // .neu-dock-dot--running
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: glyph.bottom
                        anchors.topMargin: Theme.sizeXxs
                        width: Theme.sizeXs
                        height: Theme.sizeXs
                        radius: width / 2
                        color: root.running(item.modelData.wmClass)
                                ? Theme.neuAccentText : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.fastMs } }
                    }

                    HoverHandler {
                        onHoveredChanged: root.hovered = hovered ? item.index : -1
                    }

                    TapHandler {
                        onTapped: Hyprland.dispatch("exec " + item.modelData.exec)
                    }
                }
            }
        }
    }

    // Keep the running dots honest -- Hyprland does not push toplevel changes.
    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: Hyprland.refreshToplevels()
    }
}
