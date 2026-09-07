import QtQuick
import qs
import qs.ui.neu
import qs.services

// One icon per battery, however many the machine has.
//
// The laptops in this set have either a single BAT1 or a BAT0 + BAT1 pair, and
// neu_sysinfo.sh now reports every pack in sysfs rather than the first one, so
// this is a repeater instead of a fixed module -- the two-battery machine was
// rendering only half its charge.
Row {
    id: root

    visible: Sys.batteries.length > 0
    spacing: Theme.sizeXs

    Repeater {
        model: Sys.batteries

        BarButton {
            required property var modelData

            readonly property int pct: modelData.pct
            readonly property bool charging: modelData.status === "Charging"

            icon: modelData.status === "Full" && Sys.onAc
                    ? Icons.batteryFull
                    : (charging ? Icons.ramp(Icons.batteryCharging, pct / 100)
                                : Icons.ramp(Icons.batteryRamp, pct / 100))
            label: pct + "%"

            // Colour carries the charge LEVEL, not the charge direction -- the
            // glyph already says whether the pack is filling, so spending the
            // colour on that too would leave a pack at 12% on the charger
            // looking as calm as one at 90%. Green stays for healthy-and-powered.
            tint: {
                if (pct < 15) return Theme.neuErrorText;
                if (pct < 40) return Theme.yellow;
                if (charging || Sys.onAc) return Theme.neuSuccessText;
                return Theme.neuTextMuted;
            }
        }
    }
}
