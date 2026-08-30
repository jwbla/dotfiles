import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.ui.components
import qs.ui.glance

// Slide-out RIGHT panel: the rgtv fleet at a glance — Prometheus alerts,
// Gitea PRs with CI status, per-repo master health, fleet services with
// their health probe, and Grafana dashboards. Mirror image of CommandCenter
// so the two can sit on either side of the screen. Toggled over IPC from the
// SUPER+R hyprland bind; every feed re-polls every 30s while it is open.
PanelWindow {
    id: root

    property bool shown: false

    readonly property int panelWidth: 600

    function open() {
        const mon = Hyprland.focusedMonitor;
        if (mon && mon.screen)
            root.screen = mon.screen;

        Rgtv.reload();
        shown = true;
        Rgtv.live = true;
    }

    function close() {
        shown = false;
        Rgtv.live = false;
    }

    function toggle() {
        if (shown)
            close();
        else
            open();
    }

    visible: shown || slide.running

    anchors {
        top: true
        bottom: true
        right: true
    }
    implicitWidth: panelWidth

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:rgtvglance"
    // OnDemand so Escape / r reach the panel without it stealing the keyboard
    // from the rest of the session.
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Timer {
        id: grabArm
        interval: 120
        running: root.shown
    }

    HyprlandFocusGrab {
        active: root.shown && !grabArm.running
        windows: [root]
        onCleared: root.close()
    }

    Rectangle {
        id: content

        width: root.panelWidth
        height: root.height
        color: Theme.panelBg

        // Slides in from the right edge, the mirror of CommandCenter's x.
        x: root.shown ? 0 : root.panelWidth
        opacity: root.shown ? 1 : 0

        Behavior on x {
            NumberAnimation {
                id: slide
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animDuration
            }
        }

        Rectangle {
            anchors.left: parent.left
            width: 2
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Theme.primary }
                GradientStop { position: 1.0; color: Theme.secondary }
            }
        }

        FocusScope {
            anchors.fill: parent
            focus: root.shown

            Keys.onEscapePressed: root.close()
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_R) {
                    Rgtv.reload();
                    event.accepted = true;
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.padding
                anchors.leftMargin: Theme.padding + 2
                spacing: 14

                // Header: name, one-line health summary, refresh state.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "\uf0e4"
                        color: Theme.lightPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeHeader
                    }

                    Text {
                        text: "rgtv"
                        color: Theme.sapphire
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeHeader
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.RichText
                        text: {
                            const c = (col, s) => `<font color="${col}">${s}</font>`;
                            const sep = c(Theme.overlay0, " · ");
                            // A feed that has never loaded says so rather than
                            // reporting an empty list as good news.
                            const pending = c(Theme.overlay0, "checking…");
                            const alerts = !Rgtv.alerts.loaded ? pending
                                : Rgtv.firing === 0
                                ? c(Theme.green, "0 alerts")
                                : c(Rgtv.critical ? Theme.red : Theme.peach, `${Rgtv.firing} alert${Rgtv.firing === 1 ? "" : "s"}`);
                            const nPrs = Rgtv.prs.data.length;
                            const prs = !Rgtv.prs.loaded ? pending
                                : Rgtv.prsFailing > 0
                                ? c(Theme.red, `${nPrs} PR${nPrs === 1 ? "" : "s"}, ${Rgtv.prsFailing} red`)
                                : c(Theme.subtext0, `${nPrs} PR${nPrs === 1 ? "" : "s"}`);
                            const repos = !Rgtv.repos.loaded ? pending
                                : Rgtv.reposFailing > 0
                                ? c(Theme.red, `${Rgtv.reposFailing} red master${Rgtv.reposFailing === 1 ? "" : "s"}`)
                                : c(Theme.green, "masters green");
                            const svc = !Rgtv.services.loaded ? pending
                                : Rgtv.servicesDown > 0
                                ? c(Theme.red, `${Rgtv.servicesDown} down`)
                                : c(Theme.green, `${Rgtv.servicesUp}/${Rgtv.servicesProbed} up`);
                            return [alerts, prs, repos, svc].join(sep);
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    Spinner {
                        visible: Rgtv.loading
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Text {
                        visible: !Rgtv.loading
                        text: Rgtv.lastChecked.getTime() > 0 ? `${Rgtv.ago(Rgtv.lastChecked)} ago` : ""
                        color: Theme.overlay1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Text {
                        text: "\uf021"
                        color: refreshHover.hovered ? Theme.lightPrimary : Theme.overlay1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall

                        HoverHandler {
                            id: refreshHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: Rgtv.reload()
                        }
                    }
                }

                ScrollView {
                    id: scroll

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: scroll.availableWidth
                        spacing: 14

                        AlertPane {
                            Layout.fillWidth: true
                        }

                        PrPane {
                            Layout.fillWidth: true
                            onActivated: root.close()
                        }

                        RepoPane {
                            Layout.fillWidth: true
                            onActivated: root.close()
                        }

                        ServicePane {
                            Layout.fillWidth: true
                            onActivated: root.close()
                        }

                        DashboardPane {
                            Layout.fillWidth: true
                            onActivated: root.close()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "click opens · right-click on a PR or repo → CI · r refresh · esc close"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }
        }
    }
}
