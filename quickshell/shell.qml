import Quickshell
import Quickshell.Io
import qs.services
import qs.ui
import qs.ui.bar
import qs.ui.launcher
import qs.ui.control
import qs.ui.notify
import qs.ui.switcher
import qs.ui.dev
import qs.ui.llm

ShellRoot {
    // The bar owns the top edge; hyprland.lua no longer starts waybar.
    Bar {
        id: bar
        onLauncherRequested: spotlight.toggle()
        onControlCenterRequested: control.toggle()
    }

    ControlCenter {
        id: control
    }

    // SUPER+` — local dev state; complements the rgtv fleet glance on SUPER+R.
    DevHub {
        id: devhub
    }

    // SUPER+TAB — alt-tab, replacing workspace_switcher.sh.
    Switcher {
        id: switcher
    }

    // SUPER+SPACE, replacing `wofi --show drun`.
    Spotlight {
        id: spotlight
    }

    // SUPER+I -- the local model, on the left edge. Needs ~/.config/neu/llm.env
    // pointed at an OpenAI-compatible server before it can answer anything.
    LlmPanel {
        id: llm
    }

    // The notification daemon. dunst stays configured for panic mode.
    NotificationLayer {
        id: notifications
    }

    CommandCenter {
        id: panel
    }

    RgtvGlance {
        id: glance
    }

    // Design probe for the neu primitives; not bound to a key.
    //   qs -c commandcenter ipc call probe toggle
    Playground {
        id: probe
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

    IpcHandler {
        target: "switcher"

        function next(): void {
            switcher.next();
        }

        function prev(): void {
            switcher.prev();
        }

        function confirm(): void {
            switcher.confirm();
        }

        function close(): void {
            switcher.close();
        }
    }

    IpcHandler {
        target: "dev"

        function toggle(): void {
            devhub.toggle();
        }

        function open(): void {
            devhub.open();
        }

        function close(): void {
            devhub.close();
        }
    }

    IpcHandler {
        target: "control"

        function toggle(): void {
            control.toggle();
        }

        function open(): void {
            control.open();
        }

        function close(): void {
            control.close();
        }
    }

    IpcHandler {
        target: "spotlight"

        function toggle(): void {
            spotlight.toggle();
        }

        function open(): void {
            spotlight.open();
        }

        function close(): void {
            spotlight.close();
        }
    }

    // Hyprland's SUPER+I bind shells out to:
    //   qs -c commandcenter ipc call llm toggle
    IpcHandler {
        target: "llm"

        function toggle(): void {
            llm.toggle();
        }

        function open(): void {
            llm.open();
        }

        function close(): void {
            llm.close();
        }

        // Open with the question already asked:
        //   qs -c commandcenter ipc call llm ask "why is neu-ntfy restarting?"
        function ask(prompt: string): void {
            llm.ask(prompt);
        }

        // Start a fresh conversation without touching the panel.
        function reset(): void {
            Llm.reset();
        }
    }

    IpcHandler {
        target: "probe"

        function toggle(): void {
            probe.toggle();
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
