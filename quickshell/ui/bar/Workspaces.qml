import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.ui.neu

// The centre module. Active workspace = an inset well with an accent rail,
// lifted straight from .neu-sidebar-item--active:
//     background: var(--neu-bg);
//     box-shadow: var(--neu-shadow-inset-m);
//     border-left: 3px solid var(--neu-accent-text);
// It is the same idea the DS uses for "you are here", so it means the same thing
// on the desktop as it does in the web kit.
Row {
    id: root
    spacing: Theme.sizeXs

    // Hyprland hands workspaces back in creation order, not numeric order --
    // `hyprctl workspaces` on this machine returns [1, 10, 2] -- so binding the
    // Repeater straight to the model puts them on the bar in whatever sequence
    // they happened to be made. Sort by id.
    //
    // Special workspaces (SUPER+S) carry negative ids and are dropped: they are
    // not part of the numbered strip, which is also what the waybar module this
    // replaced did by default.
    readonly property var ordered: {
        const out = [];
        for (const w of Hyprland.workspaces.values)
            if (w.id > 0)
                out.push(w);
        out.sort((a, b) => a.id - b.id);
        return out;
    }

    Repeater {
        model: root.ordered

        Item {
            id: ws
            required property var modelData

            readonly property bool active: Hyprland.focusedWorkspace
                                            && Hyprland.focusedWorkspace.id === modelData.id

            width: Math.max(28, label.implicitWidth + Theme.sizeM)
            height: Theme.barHeight - Theme.sizeS * 2

            NeuSurface {
                anchors.fill: parent
                visible: ws.active || hover.hovered
                mode: ws.active ? "inset" : "raised"
                tier: ws.active ? "m" : "xs"
                radius: Theme.radiusS
                surface: ws.active ? Theme.neuBg : Theme.neuHoverHighlight
            }

            // The accent rail.
            Rectangle {
                visible: ws.active
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                anchors.margins: 3
                width: Theme.borderM
                radius: 1
                color: Theme.neuAccentText
            }

            Text {
                id: label
                anchors.centerIn: parent
                text: ws.modelData.name
                color: ws.active ? Theme.neuText : Theme.neuTextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontM
                font.weight: ws.active ? Theme.weightSemibold : Theme.weightMedium
                Behavior on color { ColorAnimation { duration: Theme.fastMs } }
            }

            HoverHandler { id: hover }

            TapHandler {
                onTapped: Hyprland.dispatch("workspace " + ws.modelData.id)
            }
        }
    }
}
