import QtQuick
import qs
import qs.ui.neu
import qs.services

// "CI is building on this laptop right now."
//
// Same rule as LoadModule next to it: absent until it has something to say. The
// flagship laptop is a desk machine and a pair of Gitea Actions runners at the
// same time, and the only moment that second job matters to the person sitting
// at it is while a job is actually running -- which is also the moment the fans
// come up and a window takes two seconds to paint. LoadModule says the box is
// buried; this says who buried it.
//
// Blue, not the yellow/red LoadModule reddens to: a running job is the laptop
// doing its job, not a fault.
BarButton {
    id: root

    visible: Ci.active
    icon: Icons.cogs
    // The count earns its place only once there is more than one. A "1" next to
    // a glyph that already means "a job is running" is decoration.
    label: Ci.shownJobs > 1 ? Ci.shownJobs.toString() : ""
    tip: Ci.summary
    tint: Theme.neuInfoText

    onActivated: Ci.open()
}
