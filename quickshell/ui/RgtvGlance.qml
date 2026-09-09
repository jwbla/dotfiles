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
import qs.ui.neu

// Slide-out RIGHT panel: the rgtv fleet at a glance — Prometheus alerts,
// Gitea PRs with CI status, per-repo master health, fleet services with
// their health probe, and Grafana dashboards. Mirror image of CommandCenter
// so the two can sit on either side of the screen. Toggled over IPC from the
// SUPER+R hyprland bind; every feed re-polls every 30s while it is open.
PanelWindow {
    id: root

    property bool shown: false

    // Every row in here is one elided line: PR title, alert summary, service
    // name. Width is read straight off as visible characters, and 600 left a
    // title only about fifty of them once the repo#number and the timestamp
    // had taken their share. 900 still sits under half of a 1920-wide display,
    // which is what this runs on.
    readonly property int panelWidth: 900

    function open() {
        const mon = Hyprland.focusedMonitor;
        if (mon && mon.screen)
            root.screen = mon.screen;

        // Show what we already have; only go back to the fleet if it is cold.
        // `r` still forces a fresh round for when you know something changed.
        Rgtv.reloadIfStale();
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

    // A card that floats clear of the edges, the mirror of the assistant
    // sidebar rather than an edge-to-edge slab. The gradient stripe that used
    // to mark the left edge went with it: an edge accent is what you reach for
    // when a panel has no depth of its own, and this one now has relief.
    NeuSurface {
        id: content

        readonly property int margin: Theme.shadowLGap

        width: root.panelWidth - margin * 2
        y: Theme.barHeight + margin
        height: root.height - y - margin

        // Off to the right by its own width plus both margins, so nothing of it
        // is left peeking at the screen edge while closed.
        x: root.shown ? margin : root.panelWidth + margin
        opacity: root.shown ? 1 : 0

        mode: "raised"
        tier: "xl"
        radius: Theme.radiusL
        surface: Theme.neuBgCard

        Behavior on x {
            NumberAnimation {
                id: slide
                duration: Theme.defaultMs
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.baseMs
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
