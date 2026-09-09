import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.ui.neu

// The SSH phone book, as a popover under its bar button.
//
// Same shape as NotificationCenter -- a full-screen transparent sheet for the
// click-away, and a card hung off the bar -- but anchored LEFT, because the
// button lives with the launcher and the shortcuts rather than with the status
// modules. Picking a row opens a terminal on that host and closes the panel;
// there is nothing to come back to.
PanelWindow {
    id: root

    property bool shown: false

    function open() {
        const mon = Hyprland.focusedMonitor;
        if (mon && mon.screen)
            root.screen = mon.screen;
        // The two config files are read here rather than on a timer: this is
        // the only moment a stale entry could be seen.
        Ssh.reload();
        filter.text = "";
        selected = 0;
        shown = true;
        filter.forceActiveFocus();
    }

    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }

    visible: shown || fade.running
    color: "transparent"
    WlrLayershell.namespace: "neu:ssh"
    WlrLayershell.layer: WlrLayer.Overlay
    // OnDemand, like the notification centre: the filter field needs the keys,
    // but the phone book must not hold the keyboard hostage.
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    property int selected: 0

    // A filter is worth its space once the list stops fitting in one glance.
    // Two hosts out of ~/.ssh/config do not need one; a fleet phone book does.
    readonly property bool filterable: Ssh.count > 8

    // Flat rows so one ListView can carry both group headings and entries.
    readonly property var rows: {
        const q = filter.text.trim().toLowerCase();
        const hit = t => q === ""
            || t.name.toLowerCase().indexOf(q) >= 0
            || (t.detail || "").toLowerCase().indexOf(q) >= 0;
        const out = [];
        if (Ssh.grouped) {
            for (const g of Ssh.groups) {
                const items = Ssh.inGroup(g).filter(hit);
                if (items.length === 0)
                    continue;
                out.push({ kind: "header", label: g === "" ? "other" : g });
                for (const t of items)
                    out.push({ kind: "item", t: t });
            }
        } else {
            for (const t of Ssh.targets.filter(hit))
                out.push({ kind: "item", t: t });
        }
        return out;
    }

    /** Row indices that can actually be selected -- headers cannot. */
    readonly property var pickable: {
        const out = [];
        for (let i = 0; i < rows.length; i++)
            if (rows[i].kind === "item")
                out.push(i);
        return out;
    }

    function step(d) {
        if (pickable.length === 0)
            return;
        const at = pickable.indexOf(selected);
        const next = at < 0 ? 0 : Math.max(0, Math.min(pickable.length - 1, at + d));
        selected = pickable[next];
    }

    function activate(i) {
        const r = rows[i];
        if (!r || r.kind !== "item")
            return;
        close();
        Ssh.connect(r.t);
    }

    onRowsChanged: selected = pickable.length ? pickable[0] : 0

    // Click-away.
    Item {
        anchors.fill: parent
        TapHandler { onTapped: root.close() }
    }

    FocusScope {
        anchors.fill: parent
        focus: root.shown

        Keys.onEscapePressed: (event) => { root.close(); event.accepted = true; }

        NeuSurface {
            id: panel

            anchors.left: parent.left
            anchors.leftMargin: Theme.shadowLGap
            y: Theme.barHeight + Theme.shadowLGap

            implicitWidth: 360

            // Spelled out rather than taken from the column: a ListView reports
            // no implicit height of its own, so asking the column would collapse
            // the card to its chrome. Same reasoning as NotificationCenter.
            readonly property int chrome: header.implicitHeight + rule.implicitHeight
                + footer.implicitHeight + Theme.sizeL * 2 + Theme.sizeM * 3
                + (root.filterable ? search.implicitHeight + Theme.sizeM : 0)

            readonly property int ceiling:
                root.height - Theme.barHeight - Theme.shadowLGap * 2

            implicitHeight: Math.min(ceiling,
                chrome + Math.max(list.visible ? 0 : empty.implicitHeight, list.contentHeight))

            mode: "raised"
            tier: "xl"
            radius: Theme.radiusL
            surface: Theme.neuBgCard

            opacity: root.shown ? 1 : 0
            Behavior on opacity {
                NumberAnimation { id: fade; duration: Theme.baseMs }
            }

            // The card swallows every click that lands on it, so the click-away
            // sheet underneath -- a sibling of the FocusScope, still in the
            // delivery path -- never sees one. A TapHandler at the default
            // DragThreshold policy takes only a PASSIVE grab: it fires its own
            // tapped() and lets the press carry on down the stack. Without this,
            // clicking a row would close the panel by the row's own tap AND by
            // the sheet's, which is the bug the notification centre had.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.sizeL
                spacing: Theme.sizeM

                // ---- header ----------------------------------------------
                RowLayout {
                    id: header
                    Layout.fillWidth: true
                    spacing: Theme.sizeS

                    Text {
                        text: Icons.addressBook
                        color: Theme.neuAccentText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXl
                    }

                    Text {
                        text: "ssh"
                        color: Theme.neuText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXl
                        font.weight: Theme.weightBold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Ssh.count > 0 ? `${Ssh.count} hosts` : ""
                        color: Theme.neuTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXs
                        elide: Text.ElideRight
                    }
                }

                // ---- filter ----------------------------------------------
                NeuSurface {
                    id: search
                    Layout.fillWidth: true
                    visible: root.filterable
                    implicitHeight: root.filterable ? 34 : 0
                    mode: "inset"
                    tier: "s"
                    radius: Theme.radiusM
                    surface: Theme.neuBgComponent

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sizeM
                        anchors.rightMargin: Theme.sizeM
                        spacing: Theme.sizeS

                        Text {
                            text: Icons.search
                            color: Theme.neuAccentText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontM
                        }

                        TextInput {
                            id: filter
                            Layout.fillWidth: true
                            color: Theme.neuText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontM
                            selectionColor: Theme.neuAccent
                            clip: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: filter.text === ""
                                text: "filter hosts…"
                                color: Theme.neuTextDim
                                font: filter.font
                            }

                            Keys.onEscapePressed: root.close()
                            Keys.onDownPressed: root.step(1)
                            Keys.onUpPressed: root.step(-1)
                            Keys.onReturnPressed: root.activate(root.selected)
                            Keys.onEnterPressed: root.activate(root.selected)
                        }
                    }
                }

                NeuDivider {
                    id: rule
                    Layout.fillWidth: true
                }

                // ---- the book --------------------------------------------
                ListView {
                    id: list

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.rows.length > 0
                    clip: true
                    spacing: Theme.shadowXsGap
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.rows

                    ScrollBar.vertical: ScrollBar {
                        policy: list.contentHeight > list.height
                            ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    }

                    delegate: Item {
                        id: cell

                        required property int index
                        required property var modelData

                        width: list.width - (list.ScrollBar.vertical.visible ? Theme.sizeM : 0)
                        implicitHeight: modelData.kind === "header"
                            ? head.implicitHeight + Theme.sizeS
                            : row.implicitHeight

                        Text {
                            id: head
                            visible: cell.modelData.kind === "header"
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            text: cell.modelData.label || ""
                            color: Theme.neuTextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                            font.weight: Theme.weightSemibold
                        }

                        SshRow {
                            id: row
                            visible: cell.modelData.kind === "item"
                            width: parent.width
                            entry: cell.modelData.kind === "item"
                                ? cell.modelData.t
                                : ({ name: "", detail: "", source: "" })
                            selected: cell.index === root.selected
                            onActivated: root.activate(cell.index)
                        }
                    }
                }

                // ---- empty state -----------------------------------------
                ColumnLayout {
                    id: empty

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.rows.length === 0
                    spacing: Theme.sizeS

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Icons.addressBook
                        color: Theme.neuTextDim
                        opacity: 0.4
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXxxl
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: Ssh.count === 0
                            ? "no hosts yet — add ~/.ssh/config entries,\nor ~/.config/neu/ssh.json"
                            : "nothing matches"
                        color: Theme.neuTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontS
                    }

                    Item { Layout.fillHeight: true }
                }

                // ---- footer ----------------------------------------------
                Text {
                    id: footer

                    Layout.fillWidth: true
                    text: "click opens ghostty · ★ from ssh.json · esc close"
                    color: Theme.neuTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    elide: Text.ElideRight
                }
            }
        }
    }
}
