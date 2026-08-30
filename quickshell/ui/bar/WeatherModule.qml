import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.ui.neu

// Reuses waybar/weather.sh unchanged -- it already emits waybar-shaped JSON and
// handles the OpenWeatherMap -> wttr.in fallback, so there was nothing to port.
BarButton {
    id: root

    property string tooltipText: ""

    visible: label !== ""
    tint: Theme.neuTextMuted

    Process {
        id: proc
        command: ["bash", "-c", "$HOME/.config/waybar/weather.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text || "{}");
                    root.label = (d.text || "").trim();
                    root.tooltipText = d.tooltip || "";
                } catch (e) {
                    root.label = "";
                }
            }
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }

    onActivated: if (!proc.running) proc.running = true
}
