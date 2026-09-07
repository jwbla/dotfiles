import QtQuick
import qs
import qs.ui.neu
import qs.services

// The "why is everything sticky right now" indicator.
//
// Hidden while the box is keeping up, which is the point: a number that is
// always there stops being read. It appears once the 1-minute load average
// passes one runnable process per core -- the state this laptop lands in when a
// CI job is building on it -- and reddens when it is twice that.
//
// Deliberately load, not cpu%: cpu% saturates at 100% and looks identical at
// "comfortably busy" and "eight jobs deep in the run queue". The queue depth is
// the part that explains why a window took two seconds to paint.
BarButton {
    id: root

    // Local, not in Theme: these are a fact about this machine's tolerance, not
    // a design token, so they do not belong in the generated theme. Raise warn
    // if a quiet desktop is already sitting above 1.0.
    readonly property real warnAt: 1.0
    readonly property real criticalAt: 2.0

    readonly property real load: Sys.loadNorm
    readonly property bool critical: load >= criticalAt

    visible: load >= warnAt
    icon: Icons.fire
    // One decimal: the difference between 1.2 and 4.0 is the whole signal, the
    // difference between 1.21 and 1.23 is noise.
    label: load.toFixed(1)
    tint: critical ? Theme.neuErrorText : Theme.yellow
}
