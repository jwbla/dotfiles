import QtQuick
import qs
import qs.ui.neu
import qs.services

// Pinned apps in the top bar: tap to launch, or to jump to the app if it is
// already open -- across workspaces, and cycling through its windows if it has
// more than one. Windows.activate owns that decision, shared with Spotlight and
// the alt-tab switcher.
//
// The pin list itself lives in DockConfig.pinned.
Row {
    id: root

    spacing: Theme.sizeXs

    Repeater {
        model: DockConfig.pinned

        BarButton {
            required property var modelData

            icon: modelData.icon
            // Icon only. Seven names would crowd out the workspaces in the
            // centre, and these are the apps whose glyphs you already know.
            label: ""
            // Inset relief for a running app -- "raised = pressable, inset =
            // active/held" is the DS grammar, and running IS the active state.
            active: Windows.isRunning(modelData.wmClass)
            onActivated: Windows.activate(modelData.wmClass, modelData.exec)
        }
    }
}
