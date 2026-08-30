import Quickshell
import Quickshell.Io
import qs.services
import qs.ui

ShellRoot {
    CommandCenter {
        id: panel
    }

    RgtvGlance {
        id: glance
    }

    // Hyprland's SUPER+A bind shells out to:
    //   qs -c commandcenter ipc call cc toggle
    IpcHandler {
        target: "cc"

        function toggle(): void {
            panel.toggle();
        }

        function open(): void {
            panel.open();
        }

        function close(): void {
            panel.close();
        }
    }

    // Hyprland's SUPER+R bind shells out to:
    //   qs -c commandcenter ipc call rgtv toggle
    IpcHandler {
        target: "rgtv"

        function toggle(): void {
            glance.toggle();
        }

        function open(): void {
            glance.open();
        }

        function close(): void {
            glance.close();
        }

        // Re-poll every feed now (e.g. from a git hook after a push).
        function refresh(): void {
            Rgtv.reload();
        }
    }
}
