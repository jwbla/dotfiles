import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.ui.neu

// The top bar: NeuTopbar's recipe -- bg-component, --neu-shadow-drop-b as a 1px
// dark hairline along the bottom edge.
//
// The NeuOS story's menu bar is translucent over a backdrop blur. That is not
// reproducible here: hyprland.lua does set hl.layer_rule blur for the neu:*
// namespaces, but Hyprland 0.56.2 ignores it (see the note there), so a
// translucent bar would show sharp text through itself rather than a soft
// backdrop. The bar is therefore near-opaque -- the same call the pre-existing
// Command Center panel already made, for the same reason.
PanelWindow {
    id: root

    WlrLayershell.namespace: "neu:bar"
    WlrLayershell.layer: WlrLayer.Top

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: "transparent"

    signal launcherRequested()
    signal controlCenterRequested()
    signal llmRequested()
    signal sshRequested()

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Theme.neuShadowDark
        }

        // ---- left ------------------------------------------------------
        RowLayout {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: Theme.sizeS
            }
            spacing: Theme.sizeS

            // The Arch logo rather than a hamburger: three stacked lines say
            // "there is a menu here", which is the least interesting thing
            // about this corner. The distro mark says whose desktop this is,
            // and keeps the accent it always had.
            BarButton {
                icon: Icons.arch
                tip: "applications · SUPER+SPACE"
                tint: Theme.neuAccentText
                onActivated: root.launcherRequested()
            }

            // The ssh phone book, beside the shortcuts: both are "start
            // something", and neither is status.
            SshModule {
                onRequested: root.sshRequested()
            }

            Shortcuts {}

            NowPlaying {}
        }

        // ---- centre ----------------------------------------------------
        Workspaces {
            anchors.centerIn: parent
        }

        // ---- right -----------------------------------------------------
        RowLayout {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: Theme.sizeS
            }
            spacing: Theme.sizeXs

            // The two "this box is busy" modules, leftmost in a row that is
            // anchored right: both come and go, and putting them at this end
            // means their appearing extends the row leftwards instead of
            // shoving the clock and the battery sideways mid-glance.
            CiModule {}

            // Silent until the box is actually struggling.
            LoadModule {}

            TrayModule {}

            WeatherModule {}

            NetModule {}

            VolumeModule {}

            BatteryModule {}

            BarClock {}

            // The assistant, beside the bell: both are doors to a panel, and
            // both go amber when something is waiting on you.
            LlmModule {
                onRequested: root.llmRequested()
            }

            // The notification history, at the end of the row next to the
            // control centre -- the two "everything that happened / everything
            // you can change" panels sit together.
            NotifModule {}

            BarButton {
                icon: Icons.chevronDown
                tip: "control centre · SUPER+A"
                onActivated: root.controlCenterRequested()
            }
        }
    }
}
