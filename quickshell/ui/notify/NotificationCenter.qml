import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.ui.neu

// The notification history center.
//
// A popover hung off the bar's right end, the same shape as ControlCenter and
// for the same reason: it belongs to the bell it drops out of. The toasts land
// in this corner too, so the backlog opens where the thing you missed was.
//
// Open state lives on Notifs, not here, so the bar bell and the IPC handler can
// both drive it without either of them holding a reference to this window.
PanelWindow {
    id: root

    // Mirrors Notifs.centerOpen. Kept locally so open() can re-target the
    // monitor while the surface is still hidden -- re-anchoring a layer surface
    // mid-flight is what makes a panel come up on the wrong screen.
    property bool shown: false

    function open() {
        const mon = Hyprland.focusedMonitor;
        if (mon && mon.screen)
            root.screen = mon.screen;
        shown = true;
    }

    function close() {
        shown = false;
    }

    Connections {
        target: Notifs
        function onCenterOpenChanged() {
            if (Notifs.centerOpen)
                root.open();
            else
                root.close();
        }
    }

    visible: shown || fade.running
    color: "transparent"
    WlrLayershell.namespace: "neu:notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    // OnDemand: Escape has to reach the panel, but the backlog must not take the
    // keyboard away from whatever the operator was actually doing.
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    // Click-away.
    Item {
        anchors.fill: parent
        TapHandler { onTapped: Notifs.close() }
    }

    FocusScope {
        anchors.fill: parent
        focus: root.shown

        // Shift+Esc clears the backlog without closing the panel -- Slack's
        // gesture. Closing already marks everything read; this is for when you
        // want to keep reading but stop the bell nagging. Handled here rather
        // than in Keys.onPressed because escapePressed fires for Escape whatever
        // the modifiers are, and would otherwise close the panel out from under
        // the shortcut.
        Keys.onEscapePressed: (event) => {
            if (event.modifiers & Qt.ShiftModifier)
                Notifs.markAllRead();
            else
                Notifs.close();
            event.accepted = true;
        }

        NeuSurface {
            id: panel

            anchors.right: parent.right
            anchors.rightMargin: Theme.shadowLGap
            y: Theme.barHeight + Theme.shadowLGap

            implicitWidth: 420

            // Everything in the panel that is not the list. Spelled out rather
            // than taken from col.implicitHeight, because a ListView reports no
            // implicit height of its own -- asking the column would collapse the
            // panel to its chrome.
            readonly property int chrome: header.implicitHeight + rule.implicitHeight
                + footer.implicitHeight + Theme.sizeL * 2 + Theme.sizeM * 3

            readonly property int ceiling:
                root.height - Theme.barHeight - Theme.shadowLGap * 2

            implicitHeight: Math.min(ceiling,
                chrome + Math.max(list.visible ? 0 : empty.implicitHeight, list.contentHeight))

            mode: "raised"
            tier: "xl"
            radius: Theme.radiusL
            surface: Theme.neuBgCard

            opacity: root.shown ? 1 : 0
            Behavior on opacity {
                NumberAnimation { id: fade; duration: Theme.baseMs }
            }

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: Theme.sizeL
                spacing: Theme.sizeM

                // ---- header ----------------------------------------------
                RowLayout {
                    id: header
                    Layout.fillWidth: true
                    spacing: Theme.sizeS

                    Text {
                        text: Notifs.dnd ? Icons.moon : Icons.bell
                        color: Theme.neuAccentText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXl
                    }

                    Text {
                        text: "notifications"
                        color: Theme.neuText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXl
                        font.weight: Theme.weightBold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (Notifs.count === 0)
                                return "";
                            const n = `${Notifs.count} kept`;
                            return Notifs.unread > 0 ? `${n} · ${Notifs.unread} new` : n;
                        }
                        color: Theme.neuTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXs
                        elide: Text.ElideRight
                    }

                    // Do not disturb. Toasts go quiet, the history keeps filling.
                    Text {
                        text: Icons.moon
                        color: Notifs.dnd ? Theme.neuAccentText
                            : dndHover.hovered ? Theme.neuText : Theme.neuTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontM

                        HoverHandler {
                            id: dndHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler { onTapped: Notifs.toggleDnd() }
                    }

                    Text {
                        visible: Notifs.count > 0
                        text: Icons.trash
                        color: clearHover.hovered ? Theme.neuErrorText : Theme.neuTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontM

                        HoverHandler {
                            id: clearHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler { onTapped: Notifs.clear() }
                    }
                }

                NeuDivider {
                    id: rule
                    Layout.fillWidth: true
                }

                // ---- the backlog -----------------------------------------
                ListView {
                    id: list

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: Notifs.count > 0
                    clip: true
                    // Spaced by the rows' own shadow reach so their reliefs meet
                    // rather than pile up, the same rule the toast stack uses.
                    spacing: Theme.shadowXsGap
                    boundsBehavior: Flickable.StopAtBounds
                    model: Notifs.entries

                    ScrollBar.vertical: ScrollBar {
                        policy: list.contentHeight > list.height
                            ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    }

                    delegate: HistoryRow {
                        required property var modelData

                        width: list.width - (list.ScrollBar.vertical.visible ? Theme.sizeM : 0)
                        entry: modelData
                        onDismissed: Notifs.remove(modelData.key)
                    }
                }

                // ---- empty state -----------------------------------------
                ColumnLayout {
                    id: empty

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: Notifs.count === 0
                    spacing: Theme.sizeS

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Icons.bell
                        color: Theme.neuTextDim
                        opacity: 0.4
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXxxl
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "nothing to catch up on"
                        color: Theme.neuTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontS
                    }

                    Item { Layout.fillHeight: true }
                }

                // ---- footer ----------------------------------------------
                Text {
                    id: footer

                    Layout.fillWidth: true
                    text: Notifs.dnd
                        ? "do not disturb · toasts silenced except critical · history still recording"
                        : `click expands · × dismisses · keeps the last ${Notifs.cap} · esc close`
                    color: Notifs.dnd ? Theme.neuWarningText : Theme.neuTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    elide: Text.ElideRight
                }
            }
        }
    }
}
