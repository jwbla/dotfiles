import Quickshell
import Quickshell.Io
import qs.ui

ShellRoot {
    CommandCenter {
        id: panel
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
}
