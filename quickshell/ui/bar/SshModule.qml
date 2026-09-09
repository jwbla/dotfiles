import QtQuick
import qs
import qs.services
import qs.ui.neu

// The phone book's door.
//
// Deliberately NOT hidden-until-useful the way LoadModule and CiModule are: a
// status glyph earns its place by appearing when something changed, but a
// launcher earns its place by being in the same spot every time you reach for
// it. It goes quiet only when there is genuinely nothing to dial -- no ssh
// config, no ssh.json.
//
// It sits with the launcher and the shortcuts on the left rather than out with
// the status modules, because that is what it is: a way to start something.
BarButton {
    id: root

    signal requested()

    visible: Ssh.count > 0
    icon: Icons.addressBook
    tip: `ssh · ${Ssh.count} host${Ssh.count === 1 ? "" : "s"} · SUPER+P`
    tint: Theme.neuTextMuted

    onActivated: root.requested()
}
