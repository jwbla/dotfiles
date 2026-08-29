import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

// Slide-out left panel fusing Taskwarrior, Timewarrior and the tms tmux
// projects. Toggled over IPC from the SUPER+A hyprland bind.
PanelWindow {
    id: root

    property bool shown: false

    readonly property int panelWidth: 460

    function open() {
        // Follow the focused monitor, but only ever re-target while hidden so
        // the layer surface is never re-anchored mid-flight.
        const mon = Hyprland.focusedMonitor;
        if (mon && mon.screen)
            root.screen = mon.screen;

        Tasks.reload();
        Timew.reload();
        Tmux.reload();
        shown = true;
        setLive(true);
    }

    function close() {
        shown = false;
        setLive(false);
    }

    // The services' refresh polls and the 1s Timewarrior tick only run while
    // the panel is actually on screen.
    function setLive(on) {
        Tasks.live = on;
        Timew.live = on;
    }

    function toggle() {
        if (shown)
            close();
        else
            open();
    }

    visible: shown || slide.running

    anchors {
        top: true
        bottom: true
        left: true
    }
    implicitWidth: panelWidth

    // Overlay the tiled layout instead of reflowing it.
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:commandcenter"
    // OnDemand, not Exclusive: the add-task field needs keys, but the panel
    // must not swallow the keyboard from the rest of the session.
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Arming the grab on the same frame as the opening keypress makes it eat
    // its own event, so give the compositor a beat first.
    Timer {
        id: grabArm
        interval: 120
        running: root.shown
    }

    HyprlandFocusGrab {
        active: root.shown && !grabArm.running
        windows: [root]
        onCleared: root.close()
    }

    Rectangle {
        id: content

        // Both the width and the slide offset come from the constant, not from
        // `parent` or from `width`: the contentItem sizes itself to its
        // children, so any of those makes x depend on something x feeds.
        width: root.panelWidth
        height: root.height
        color: Theme.panelBg

        x: root.shown ? 0 : -root.panelWidth
        opacity: root.shown ? 1 : 0

        Behavior on x {
            NumberAnimation {
                id: slide
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animDuration
            }
        }

        Rectangle {
            anchors.right: parent.right
            width: 2
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Theme.primary }
                GradientStop { position: 1.0; color: Theme.secondary }
            }
        }

        FocusScope {
            anchors.fill: parent
            focus: root.shown

            Keys.onEscapePressed: root.close()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.padding
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: Qt.formatDateTime(clock.now, "ddd MMM dd")
                        color: Theme.sapphire
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeHeader
                        font.bold: true
                    }

                    Text {
                        text: Qt.formatDateTime(clock.now, "HH:mm")
                        color: Theme.overlay1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeHeader
                    }
                }

                TimePane {
                    Layout.fillWidth: true
                }

                TaskPane {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                TmuxPane {
                    Layout.fillWidth: true
                    onActivated: root.close()
                }
            }
        }
    }

    QtObject {
        id: clock
        property date now: new Date()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.shown
        triggeredOnStart: true
        onTriggered: clock.now = new Date()
    }
}
