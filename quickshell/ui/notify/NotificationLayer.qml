import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs
import qs.ui.neu

// The notification daemon, replacing dunst.
//
// .neu-toast, ported: 280-420px, --neu-shadow-l, a 4px accent rail down the left
// edge tinted by urgency, slide-in 0.35s ease-out / fade-out 0.3s ease-in, and
// the countdown ring around the close button.
PanelWindow {
    id: root

    WlrLayershell.namespace: "neu:notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors { top: true; right: true; bottom: true }
    implicitWidth: 460
    visible: server.trackedNotifications.values.length > 0

    NotificationServer {
        id: server
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (n) => {
            n.tracked = true;
        }
    }

    ColumnLayout {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: Theme.barHeight + Theme.shadowLGap
            rightMargin: Theme.shadowLGap
        }
        // Space toasts by the shadow's reach so their reliefs meet, never overlap.
        spacing: Theme.shadowLGap

        Repeater {
            model: server.trackedNotifications

            Toast {
                required property var modelData
                notification: modelData
            }
        }
    }
}
