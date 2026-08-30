import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.ui.neu

// Spotlight -- .neu-command-palette, on the desktop.
//
// Replaces `wofi --show drun` on SUPER+SPACE and absorbs what workspace_switcher.sh
// and tmux-wofi.sh did, so one surface answers "take me to a thing" whatever the
// thing is. wofi stays installed for --dmenu callers and for panic mode.
PanelWindow {
    id: root

    property bool shown: false

    visible: shown
    color: "transparent"
    WlrLayershell.namespace: "neu:spotlight"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    function open() {
        input.text = "";
        selected = 0;
        Apps.reload();
        shown = true;
        input.forceActiveFocus();
    }

    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }

    property int selected: 0

    // ---- the item pool -------------------------------------------------

    readonly property var systemActions: [
        { group: "System", icon: Icons.power,  name: "Lock screen",   run: () => Hyprland.dispatch("exec hyprlock") },
        { group: "System", icon: Icons.refresh, name: "Reload Hyprland", run: () => Hyprland.dispatch("reload") },
        { group: "System", icon: Icons.cog,    name: "Restart the neu shell", run: () => Hyprland.dispatch("exec ~/.local/bin/neu-shell.sh") },
        { group: "System", icon: Icons.warning, name: "Panic: back to waybar", run: () => Hyprland.dispatch("exec ~/.local/bin/neu-panic.sh") }
    ]

    readonly property var pool: {
        const out = [];
        for (const a of Apps.apps)
            out.push({ group: "Applications", icon: Icons.app, name: a.name,
                       hint: a.comment || "", app: a });
        for (const w of Hyprland.workspaces.values)
            out.push({ group: "Workspaces", icon: Icons.workspace,
                       name: "Workspace " + w.name,
                       run: () => Hyprland.dispatch("workspace " + w.id) });
        for (const p of Tmux.projects)
            out.push({ group: "tmux", icon: Icons.terminal, name: p.name,
                       hint: p.running ? "running" : "",
                       run: () => Tmux.attach(p.name) });
        return out.concat(systemActions);
    }

    readonly property var results: {
        const q = input.text.trim().toLowerCase();
        let list = pool;
        if (q !== "") {
            list = pool
                .map(i => {
                    const n = i.name.toLowerCase();
                    const idx = n.indexOf(q);
                    // Prefix beats substring beats a hit only in the description.
                    const score = idx === 0 ? 0 : idx > 0 ? 1
                                : (i.hint || "").toLowerCase().includes(q) ? 2 : -1;
                    return { i: i, score: score, idx: idx < 0 ? 999 : idx };
                })
                .filter(x => x.score >= 0)
                .sort((a, b) => a.score - b.score || a.idx - b.idx
                             || a.i.name.localeCompare(b.i.name))
                .map(x => x.i);
        }
        return list.slice(0, 40);
    }

    function activate(item) {
        if (!item) return;
        close();
        if (item.app) Apps.launch(item.app);
        else if (item.run) item.run();
    }

    // ---- chrome --------------------------------------------------------

    // .neu-command-overlay: color-mix(in srgb, var(--neu-shadow-dark) 45%, transparent)
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.neuShadowDark.r, Theme.neuShadowDark.g,
                       Theme.neuShadowDark.b, 0.45)

        TapHandler { onTapped: root.close() }
    }

    NeuSurface {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        // padding-top: 14vh, width: min(36rem, 100vw - 2rem)
        y: root.height * 0.14
        width: Math.min(576, root.width - 32)
        height: Math.min(root.height * 0.6, header.height + list.contentHeight + Theme.sizeL * 2)

        mode: "raised"
        tier: "xl"
        radius: Theme.radiusL
        surface: Theme.neuBgCard

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.985
        Behavior on opacity { NumberAnimation { duration: Theme.baseMs; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.baseMs; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.sizeS
            spacing: Theme.sizeS

            // .neu-command-input -- an inset entry field pinned to the top
            NeuSurface {
                id: header
                Layout.fillWidth: true
                implicitHeight: 46
                mode: "inset"
                tier: "s"
                radius: Theme.radiusM
                surface: Theme.neuBgComponent

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.sizeL
                    anchors.rightMargin: Theme.sizeL
                    spacing: Theme.sizeS

                    Text {
                        text: Icons.search
                        color: Theme.neuAccentText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontL
                    }

                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        color: Theme.neuText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontL
                        selectionColor: Theme.neuAccent
                        clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: "Search apps, workspaces, tmux…"
                            color: Theme.neuTextDim
                            font: input.font
                        }

                        onTextChanged: root.selected = 0

                        Keys.onEscapePressed: root.close()
                        Keys.onDownPressed: root.selected = Math.min(root.selected + 1, root.results.length - 1)
                        Keys.onUpPressed: root.selected = Math.max(root.selected - 1, 0)
                        Keys.onReturnPressed: root.activate(root.results[root.selected])
                        Keys.onEnterPressed: root.activate(root.results[root.selected])
                        Keys.onTabPressed: root.selected = (root.selected + 1) % Math.max(1, root.results.length)
                    }

                    Text {
                        text: root.results.length + ""
                        color: Theme.neuTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXs
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.results
                currentIndex: root.selected
                highlightMoveDuration: Theme.fastMs
                spacing: 2

                // Keep the selection on screen when arrowing past the fold.
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: 40

                    readonly property bool active: index === root.selected
                    readonly property bool newGroup: index === 0
                        || root.results[index - 1].group !== modelData.group

                    // .neu-command-option--active: inset + accent glow + accent text
                    NeuSurface {
                        anchors.fill: parent
                        anchors.margins: 2
                        visible: parent.active || hover.hovered
                        mode: parent.active ? "inset" : "flat"
                        tier: "s"
                        radius: Theme.radiusS
                        surface: parent.active ? Theme.neuBgComponent : Theme.neuHoverHighlight
                        glow: parent.active ? Theme.neuAccent : "transparent"
                        glowBlur: Theme.sizeXs
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sizeM
                        anchors.rightMargin: Theme.sizeM
                        spacing: Theme.sizeM

                        Text {
                            text: modelData.icon
                            color: parent.parent.active ? Theme.neuAccentText : Theme.neuTextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontL
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                            color: parent.parent.active ? Theme.neuAccentText : Theme.neuText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontM
                        }

                        // .neu-command-group -- uppercase, 0.06em, dim
                        Text {
                            text: modelData.group.toUpperCase()
                            visible: parent.parent.newGroup
                            color: Theme.neuTextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                            font.weight: Theme.weightSemibold
                            font.letterSpacing: Theme.fontXs * Theme.trackingGroup
                        }
                    }

                    HoverHandler {
                        id: hover
                        onHoveredChanged: if (hovered) root.selected = index
                    }

                    TapHandler {
                        onTapped: root.activate(modelData)
                    }
                }
            }
        }
    }
}
