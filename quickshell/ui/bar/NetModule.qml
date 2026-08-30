import QtQuick
import qs
import qs.ui.neu
import qs.services

BarButton {
    id: root

    icon: {
        if (!Sys.netUp) return Icons.wifiOff;
        if (Sys.netKind === "ethernet") return Icons.ethernet;
        return Icons.ramp(Icons.wifiRamp, Sys.netQuality);
    }
    label: Sys.netUp ? Sys.netName : "offline"
    tint: Sys.netUp ? Theme.neuTextMuted : Theme.neuErrorText
}
