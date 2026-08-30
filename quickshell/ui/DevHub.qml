import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.ui.neu

// Dev Hub -- SUPER+`
//
// A starting point, not a finished idea: the repos under ~/dev that are actually
// in flight, with branch, working-tree state, drift from upstream, and whether a
// tmux session is already up. Click a row to attach or create that session in a
// terminal.
PanelWindow {
    id: root

    property bool shown: false

    visible: shown
    color: "transparent"
    WlrLayershell.namespace: "neu:devhub"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    function open() {
        Dev.live = true;
        Dev.reload();
        shown = true;
    }
    function close() { shown = false; Dev.live = false; }
    function toggle() { shown ? close() : open(); }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.neuShadowDark.r, Theme.neuShadowDark.g,
                       Theme.neuShadowDark.b, 0.45)
        TapHandler { onTapped: root.close() }
    }

    NeuSurface {
        anchors.centerIn: parent
        width: Math.min(760, root.width - Theme.sizeXxl * 2)
        // Not col.implicitHeight: the repo ListView fills height, so it
        // contributes 0 and the panel would collapse to header + footer.
        height: Math.min(root.height * 0.78,
                         Math.max(280, Dev.repos.length * 46 + 170))

        mode: "raised"
        tier: "xl"
        radius: Theme.radiusL
        surface: Theme.neuBgCard

        Keys.onEscapePressed: root.close()

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.sizeXl
            spacing: Theme.sizeL

            // ---- header ---------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sizeS

                Text {
                    text: Icons.git
                    color: Theme.neuAccentText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXl
                }

                Text {
                    text: "dev hub"
                    color: Theme.neuText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXl
                    font.weight: Theme.weightBold
                }

                NeuSpinner {
                    visible: Dev.loading
                    Layout.leftMargin: Theme.sizeXs
                }

                Item { Layout.fillWidth: true }

                NeuChip {
                    label: "dirty"
                    value: Dev.dirtyCount + ""
                    valueColor: Dev.dirtyCount > 0 ? Theme.neuWarningText : Theme.neuTextMuted
                }

                NeuChip {
                    label: "ahead"
                    value: Dev.aheadCount + ""
                    valueColor: Dev.aheadCount > 0 ? Theme.neuAccentText : Theme.neuTextMuted
                }

                NeuChip {
                    label: "tmux"
                    value: Dev.sessions.length + ""
                    valueColor: Dev.sessions.length > 0 ? Theme.neuSuccessText : Theme.neuTextMuted
                }
            }

            NeuDivider { Layout.fillWidth: true }

            // ---- repos ----------------------------------------------------
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: Dev.repos

                delegate: Item {
                    required property var modelData
                    width: ListView.view.width
                    height: 46

                    NeuSurface {
                        anchors.fill: parent
                        anchors.margins: 1
                        visible: hover.hovered
                        mode: "raised"
                        tier: "xxs"
                        radius: Theme.radiusS
                        surface: Theme.neuHoverHighlight
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sizeM
                        anchors.rightMargin: Theme.sizeM
                        spacing: Theme.sizeM

                        // running dot, same language as the dock
                        Rectangle {
                            Layout.preferredWidth: Theme.sizeS
                            Layout.preferredHeight: Theme.sizeS
                            radius: width / 2
                            color: modelData.session ? Theme.neuSuccessText : "transparent"
                            border.width: modelData.session ? 0 : 1
                            border.color: Theme.neuTextDim
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.sizeS

                                Text {
                                    text: modelData.name
                                    color: Theme.neuText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontM
                                    font.weight: Theme.weightSemibold
                                }

                                Text {
                                    text: modelData.branch
                                    color: Theme.neuAccentLight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontS
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.subject
                                elide: Text.ElideRight
                                color: Theme.neuTextDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontXs
                            }
                        }

                        NeuBadge {
                            visible: modelData.dirty > 0
                            tone: "warning"
                            text: modelData.dirty + " dirty"
                        }

                        NeuBadge {
                            visible: modelData.ahead > 0
                            tone: "accent"
                            text: "↑" + modelData.ahead
                        }

                        NeuBadge {
                            visible: modelData.behind > 0
                            tone: "info"
                            text: "↓" + modelData.behind
                        }

                        NeuBadge {
                            visible: modelData.stashes > 0
                            tone: "neutral"
                            text: modelData.stashes + " stash"
                        }
                    }

                    HoverHandler { id: hover }

                    TapHandler {
                        onTapped: {
                            root.close();
                            Dev.open(modelData);
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "click a repo to attach its tmux session · esc to close"
                color: Theme.neuTextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
            }
        }
    }
}
