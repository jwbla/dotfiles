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
    onScrolled: (d) => Sys.setVolume(Sys.volumePct + d * 5)
}
