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

            BarButton {
                icon: Icons.menu
                tint: Theme.neuAccentText
                onActivated: root.launcherRequested()
            }

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

            TrayModule {}

            WeatherModule {}

            NetModule {}

            VolumeModule {}

            BatteryModule {}

            BarClock {}

            BarButton {
                icon: Icons.chevronDown
                onActivated: root.controlCenterRequested()
            }
        }
    }
}
