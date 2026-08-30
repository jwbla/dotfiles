import QtQuick
import qs
import qs.ui.neu
import qs.services

// One battery, not two. The waybar config declared battery#bat0 AND battery#bat1
// but this machine only has BAT1 in sysfs, so the bar has been rendering a dead
// module; Sys reads whatever batteries actually exist.
BarButton {
    id: root

    readonly property real frac: Sys.batteryPct / 100

    visible: Sys.batteryPresent
    icon: Sys.batteryStatus === "Full" && Sys.onAc
            ? Icons.batteryFull
            : (Sys.charging ? Icons.ramp(Icons.batteryCharging, frac)
                            : Icons.ramp(Icons.batteryRamp, frac))
    label: Sys.batteryPct + "%"

    tint: {
        if (Sys.charging || Sys.onAc) return Theme.neuSuccessText;
        if (Sys.batteryPct <= 10) return Theme.neuErrorText;
        if (Sys.batteryPct <= 25) return Theme.neuWarningText;
        return Theme.neuTextMuted;
    }
}
