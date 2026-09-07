import QtQuick
import qs
import qs.ui.neu
import qs.services

BarButton {
    id: root

    icon: Sys.muted ? Icons.volMuted
                    : (Sys.volumePct < 50 ? Icons.volLow : Icons.volHigh)
    label: Sys.muted ? "muted" : Sys.volumePct + "%"
    tint: Sys.muted ? Theme.neuTextDim : Theme.neuTextMuted

    onActivated: Sys.toggleMute()

    // Scrolling up on a muted sink unmutes it. Otherwise the wheel moves a
    // number nobody can hear and the module looks broken -- which is exactly
    // how it looked, because the label reads "muted" and never shows the level.
    onScrolled: (d) => {
        if (Sys.muted && d > 0) Sys.setMuted(false);
        Sys.nudgeVolume(d * 5);
    }
}
