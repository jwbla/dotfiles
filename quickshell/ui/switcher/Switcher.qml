import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.ui.neu

// Alt-tab, properly.
//
// The old SUPER+TAB shelled out to workspace_switcher.sh, which meant a fresh
// wofi process per press. This stays open across presses: the first SUPER+TAB
// opens it on the previously-used window (the classic behaviour -- one tap
// bounces between your last two), each further press advances, and releasing
// SUPER commits. Escape or a click anywhere dismisses without switching.
//
// The candidate list is snapshotted when the switcher opens. It has to be:
// focusing a window rewrites focusHistoryID, so a live list would reshuffle
// underneath you mid-cycle.
PanelWindow {
    id: root

    property bool shown: false
    property var items: []
    property int selected: 0

    visible: shown
    color: "transparent"
    WlrLayershell.namespace: "neu:switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    function snapshot() {
        // Windows is polled continuously, so this is the already-fetched list.
        // Calling reload() here and reading straight back would return the
        // previous answer -- the Process has not run yet.
        items = Windows.windows.slice();
        Windows.reload();
    }

    function next() {
        if (!shown) {
            snapshot();
            if (items.length < 2)
                return;
            // Start on the previous window, not the current one.
            selected = 1;
            shown = true;
            focusScope.forceActiveFocus();
        } else {
            selected = (selected + 1) % Math.max(1, items.length);
        }
    }

    function prev() {
        if (!shown) {
            snapshot();
            if (items.length < 2)
                return;
            selected = items.length - 1;
            shown = true;
            focusScope.forceActiveFocus();
        } else {
            selected = (selected - 1 + items.length) % Math.max(1, items.length);
        }
    }

    function confirm() {
        if (!shown)
            return;
        const w = items[selected];
        shown = false;
        if (w)
            Windows.focus(w.address);
    }

    function close() { shown = false; }

    // Keep the snapshot warm so the first press has no latency.
    Component.onCompleted: Windows.reload()

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.neuShadowDark.r, Theme.neuShadowDark.g,
                       Theme.neuShadowDark.b, 0.45)
        TapHandler { onTapped: root.close() }
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent

        Keys.onEscapePressed: root.close()

        // Releasing SUPER commits, the way alt-tab does. The Hyprland release
        // bind is a belt-and-braces fallback for the case where the press
        // happened before this surface took focus and the release is delivered
        // as a modifier update rather than a key event.
        Keys.onReleased: (e) => {
            if (e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R
                || e.key === Qt.Key_Meta) {
                e.accepted = true;
                root.confirm();
            }
        }
        Keys.onReturnPressed: root.confirm()
        Keys.onRightPressed: root.next()
        Keys.onLeftPressed: root.prev()

        NeuSurface {
            anchors.centerIn: parent
            implicitWidth: Math.min(root.width - Theme.sizeXxl * 2,
                                    row.implicitWidth + Theme.sizeXl * 2)
            implicitHeight: row.implicitHeight + Theme.sizeXl * 2

            mode: "raised"
            tier: "xl"
            radius: Theme.radiusL
            surface: Theme.neuBgCard

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: Theme.shadowSGap

                Repeater {
                    model: root.items

                    // Each candidate is a NeuTile-shaped card: raised when it is
                    // just sitting there, inset + accent when it is the one you
                    // are about to land on. Same grammar as everything else.
                    NeuSurface {
                        id: card
                        required property var modelData
                        required property int index

                        readonly property bool active: index === root.selected

                        implicitWidth: 132
                        implicitHeight: 108

                        mode: active ? "inset" : "raised"
                        tier: active ? "s" : "xs"
                        radius: Theme.radiusM
                        surface: active ? Theme.neuBg : Theme.neuBgComponent
                        glow: active ? Theme.neuAccent : "transparent"
                        glowBlur: Theme.sizeXs

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.sizeS
                            spacing: Theme.sizeXs

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Windows.iconFor(card.modelData.class)
                                color: card.active ? Theme.neuAccentText : Theme.neuTextMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontXxxl
                                Behavior on color { ColorAnimation { duration: Theme.fastMs } }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                horizontalAlignment: Text.AlignHCenter
                                text: card.modelData.title
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                                color: card.active ? Theme.neuText : Theme.neuTextDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontXs
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "ws " + card.modelData.workspace.name
                                color: Theme.neuTextDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontXs
                                font.weight: Theme.weightSemibold
                                font.letterSpacing: Theme.fontXs * Theme.trackingStat
                            }
                        }

                        HoverHandler {
                            onHoveredChanged: if (hovered) root.selected = card.index
                        }

                        TapHandler { onTapped: root.confirm() }
                    }
                }
            }
        }
    }
}
