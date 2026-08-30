import QtQuick
import Quickshell
import qs
import qs.ui.neu

// The clock reads as the bar's anchor, so it takes --neu-text while its
// neighbours sit at --neu-text-muted. Tabular figures stop the row twitching
// every minute.
BarButton {
    id: root

    property bool showDate: false

    label: showDate ? Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
                    : Qt.formatDateTime(clock.date, "HH:mm")
    tint: Theme.neuText

    onActivated: showDate = !showDate

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
