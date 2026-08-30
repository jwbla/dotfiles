import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.ui.neu

// The Control Center popover, hung off the bar's right end.
//
// Tiles follow the NeuOS story's inversion: an ACTIVE toggle is flat and
// accent-filled (it is held), an inactive one is raised (it is pressable).
// The load row uses NeuMeter, whose unlit segments carry a 14% tint of their own
// zone colour so the green/amber/red bands read even when nothing is lit.
PanelWindow {
    id: root

    property bool shown: false

    visible: shown
    color: "transparent"
    WlrLayershell.namespace: "neu:control"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    function open() { shown = true; }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }

    Item {
        anchors.fill: parent
        TapHandler { onTapped: root.close() }
    }

    NeuSurface {
        id: panel

        anchors.right: parent.right
        anchors.rightMargin: Theme.shadowLGap
        y: Theme.barHeight + Theme.shadowLGap

        // Wide enough for four tiles plus their shadow reach and the panel
        // margins: 4*76 + 3*9 + 2*16. Sized rather than guessed, because every
        // row below fills this width -- a narrower panel silently overflowed.
        implicitWidth: 4 * 76 + 3 * Theme.shadowSGap + Theme.sizeXl * 2
        implicitHeight: col.implicitHeight + Theme.sizeXl * 2

        mode: "raised"
        tier: "xl"
        radius: Theme.radiusL
        surface: Theme.neuBgCard

        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.baseMs } }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.sizeXl
            spacing: Theme.sizeL

            // ---- toggles -------------------------------------------------
            GridLayout {
                columns: 4
                columnSpacing: Theme.shadowSGap
                rowSpacing: Theme.shadowSGap
                Layout.fillWidth: true

                NeuTile {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    icon: Sys.netUp ? Icons.wifiIcon : Icons.wifiOff
                    label: Sys.netUp ? "wifi" : "offline"
                    active: Sys.netUp
                }

                NeuTile {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    icon: Sys.muted ? Icons.volMuted : Icons.volHigh
                    label: Sys.muted ? "muted" : "sound"
                    active: !Sys.muted
                    onToggled: Sys.toggleMute()
                }

                NeuTile {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    icon: Icons.moon
                    label: "focus"
                    active: root.dnd
                    onToggled: root.dnd = !root.dnd
                }

                NeuTile {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    icon: Icons.power
                    label: "lock"
                    onToggled: {
                        root.close();
                        Hyprland.dispatch("exec hyprlock");
                    }
                }
            }

            NeuDivider { Layout.fillWidth: true }

            // ---- volume --------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sizeM

                Text {
                    text: Sys.muted ? Icons.volMuted : Icons.volHigh
                    color: Theme.neuTextMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontL
                }

                NeuSlider {
                    Layout.fillWidth: true
                    value: Sys.volumePct / 100
                    onMoved: (v) => Sys.setVolume(v * 100)
                }

                Text {
                    text: Sys.volumePct + "%"
                    color: Theme.neuText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontS
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 40
                }
            }

            NeuDivider { Layout.fillWidth: true }

            // ---- load ----------------------------------------------------
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: Theme.sizeM

                Repeater {
                    model: [
                        { icon: Icons.cpu,    label: "CPU",  v: Sys.cpu },
                        { icon: Icons.memory, label: "MEM",  v: Sys.mem },
                        { icon: Icons.disk,   label: "DISK", v: Sys.disk }
                    ]

                    ColumnLayout {
                        required property var modelData
                        spacing: Theme.sizeXs
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0

                        NeuMeter {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            value: modelData.v
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label + " " + Math.round(modelData.v * 100) + "%"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.neuTextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                            font.weight: Theme.weightSemibold
                            font.letterSpacing: Theme.fontXs * Theme.trackingStat
                        }
                    }
                }
            }

            NeuDivider { Layout.fillWidth: true }

            // ---- footer --------------------------------------------------
            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Sys.batteryPresent
                          ? (Sys.batteryPct + "%  " + Sys.batteryStatus.toLowerCase())
                          : "no battery"
                    color: Theme.neuTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: Sys.netUp ? Sys.netName : "offline"
                    color: Theme.neuTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                }
            }
        }
    }

    property bool dnd: false
}
