import QtQuick
import qs
import qs.services
import qs.ui.neu

// The bell: the way into the notification history, and the only standing sign
// that there is a backlog at all.
//
// Always present, unlike LoadModule -- this one is a door, not a warning, and a
// door that appears only when it has something behind it is a door nobody knows
// about. What changes is the count beside it and the colour: accent for unread,
// error if anything unread was critical, so the bar can say "you missed
// something that mattered" without opening anything.
BarButton {
    id: root

    readonly property int unread: Notifs.unread

    icon: Notifs.dnd ? Icons.moon : Icons.bell
    // No count while do-not-disturb is on: the moon is the headline then, and a
    // number next to it reads as "muted, and also nagging".
    label: !Notifs.dnd && unread > 0 ? String(unread) : ""

    tint: Notifs.dnd ? Theme.neuTextDim
        : Notifs.unreadCritical ? Theme.neuErrorText
        : unread > 0 ? Theme.neuAccentText
        : Theme.neuTextMuted

    active: Notifs.centerOpen

    onActivated: Notifs.toggle()
    // Right-click is do-not-disturb, next to the thing it silences.
    onSecondaryActivated: Notifs.toggleDnd()
}
