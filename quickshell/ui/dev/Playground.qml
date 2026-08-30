import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.ui.neu

// Design probe -- the desktop's answer to shadow-playground.stories.tsx.
// Every relief tier on the real ground, so the shadow grammar can be checked
// against the design system instead of guessed at.
//
//   qs -c commandcenter ipc call probe toggle
PanelWindow {
    id: root

    property bool shown: false

    visible: shown
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "neu:probe"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    function toggle() { shown = !shown; }

    Rectangle {
        anchors.fill: parent
        color: Theme.neuBg

        MouseArea {
            anchors.fill: parent
            onClicked: root.shown = false
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.sizeXl

            Text {
                text: "NeuSurface — shadow grammar"
                color: Theme.neuText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXxl
                font.weight: Theme.weightBold
            }

            // raised: pressable
            RowLayout {
                spacing: Theme.shadowXlGap
                Repeater {
                    model: ["xxs", "xs", "s", "m", "l", "xl"]
                    delegate: NeuSurface {
                        required property string modelData
                        implicitWidth: 96
                        implicitHeight: 64
                        mode: "raised"
                        tier: modelData
                        Text {
                            anchors.centerIn: parent
                            text: parent.parent.modelData
                            color: Theme.neuTextMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontS
                        }
                    }
                }
            }

            // inset: active / held / a well
            RowLayout {
                spacing: Theme.shadowXlGap
                Repeater {
                    model: ["xs", "s", "m", "l"]
                    delegate: NeuSurface {
                        required property string modelData
                        implicitWidth: 96
                        implicitHeight: 64
                        mode: "inset"
                        tier: modelData
                        Text {
                            anchors.centerIn: parent
                            text: "in " + parent.parent.modelData
                            color: Theme.neuTextMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontS
                        }
                    }
                }

                NeuSurface {
                    implicitWidth: 96
                    implicitHeight: 64
                    mode: "flat"
                    disabled: true
                    Text {
                        anchors.centerIn: parent
                        text: "flat"
                        color: Theme.neuTextMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontS
                    }
                }
            }

            // glow: status tint stacked on the raised pair
            RowLayout {
                spacing: Theme.shadowXlGap
                Repeater {
                    model: [
                        { c: Theme.neuAccent,  t: Theme.neuAccentText,  l: "accent" },
                        { c: Theme.neuSuccess, t: Theme.neuSuccessText, l: "success" },
                        { c: Theme.neuWarning, t: Theme.neuWarningText, l: "warning" },
                        { c: Theme.neuError,   t: Theme.neuErrorText,   l: "error" },
                        { c: Theme.neuInfo,    t: Theme.neuInfoText,    l: "info" }
                    ]
                    delegate: NeuSurface {
                        required property var modelData
                        implicitWidth: 96
                        implicitHeight: 48
                        tier: "l"
                        radius: Theme.radiusL
                        glow: modelData.c
                        Text {
                            anchors.centerIn: parent
                            text: parent.parent.modelData.l
                            color: parent.parent.modelData.t
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontS
                        }
                    }
                }
            }

            Text {
                text: "click anywhere to dismiss"
                color: Theme.neuTextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
