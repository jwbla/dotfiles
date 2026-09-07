import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs
import qs.services
import qs.ui.neu

// The notification subsystem, replacing dunst: the daemon, the toasts it throws,
// and the history center that remembers them afterwards.
//
// A Scope rather than the toast window directly, because there are now three
// surfaces to this and shell.qml should keep instantiating exactly one thing.
// The toast stack and the center never reference each other -- both go through
// the Notifs singleton -- so the center opens from the bar bell and from IPC
// without either of them reaching in here.
Scope {
    id: root

    NotificationServer {
        id: server

        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (n) => {
            // History first, and unconditionally. Everything below this line is
            // about whether to INTERRUPT; none of it is about whether to
            // remember, or do-not-disturb would be a delete button.
            Notifs.record(n);

            // Tracking is what puts a notification in front of the operator.
            // Leaving it untracked while DND is on drops the toast and nothing
            // else -- the record above already happened.
            //
            // Critical still gets through. Do-not-disturb on this box has to
            // coexist with fleet alerts arriving over ntfy at urgency=critical,
            // and a mode that can swallow "the array is degraded" is not a
            // focus mode, it is an outage waiting to be blamed on a quiet
            // night. Suppress everything below critical, nothing above it.
            if (!Notifs.dnd || n.urgency === NotificationUrgency.Critical)
                n.tracked = true;
        }
    }

    // ---- toasts --------------------------------------------------------
    //
    // .neu-toast, ported: 280-420px, --neu-shadow-l, a 4px accent rail down the
    // left edge tinted by urgency, slide-in 0.35s ease-out / fade-out 0.3s
    // ease-in, and the countdown ring around the close button.
    PanelWindow {
        id: toasts

        WlrLayershell.namespace: "neu:notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        anchors { top: true; right: true; bottom: true }
        implicitWidth: 460
        visible: server.trackedNotifications.values.length > 0

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

    // ---- history -------------------------------------------------------

    NotificationCenter {}

    // Hyprland's SUPER+N bind shells out to:
    //   qs -c commandcenter ipc call notifs toggle
    IpcHandler {
        target: "notifs"

        function toggle(): void {
            Notifs.toggle();
        }

        function open(): void {
            Notifs.open();
        }

        function close(): void {
            Notifs.close();
        }

        /** Throw away the whole backlog. */
        function clear(): void {
            Notifs.clear();
        }

        /** Silence toasts without silencing the record. */
        function dnd(): void {
            Notifs.toggleDnd();
        }
    }
}
