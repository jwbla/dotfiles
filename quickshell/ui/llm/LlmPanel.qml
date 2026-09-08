import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.ui.neu

// The assistant sidebar -- SUPER+I, slides in from the left edge.
//
// Left on purpose: the right edge already carries the control center and the
// rgtv glance, and this one is meant to stay open next to what you are doing
// rather than being summoned and dismissed.
//
// Keyboard focus is Exclusive while open, like Spotlight, because the first
// thing you do with a chat panel is type into it and OnDemand would need a
// click first. Escape closes; so does a click on the desktop beside it.
PanelWindow {
    id: root

    property bool shown: false

    visible: shown
    color: "transparent"
    WlrLayershell.namespace: "neu:llm"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    function open() {
        if (!shown) {
            // The conversation lives in the service, which outlives this
            // window, so reopening shows whatever was already there --
            // including a turn still streaming and a permission still waiting.
            // Only a panel with nothing in it needs the stored history read.
            if (Llm.chat.count === 0 && !Llm.busy)
                Llm.reload();
            else
                Llm.refresh();
            shown = true;
        }
        Llm.panelOpen = true;
        Llm.unread = false;   // you are looking at it now
        input.forceActiveFocus();
    }

    function close() {
        shown = false;
        picker.open = false;
        Llm.panelOpen = false;
    }
    function toggle() { shown ? close() : open(); }

    // Open with a question already asked, for a keybind or a script that has
    // context this panel does not -- "explain this failing unit", say.
    function ask(prompt) {
        open();
        Llm.send(prompt);
    }

    // host:port is the only part of the endpoint worth the header's one line.
    readonly property string where: Llm.endpoint
        .replace(/^https?:\/\//, "").replace(/\/v1\/?$/, "")

    Connections {
        target: Llm
        function onSummoned(prefill) {
            root.open();
            if (prefill !== "") {
                input.text = prefill;
                input.cursorPosition = input.text.length;
            }
        }
    }

    // Click off the panel to dismiss it.
    //
    // Decided by geometry, not by event propagation. The controls in here are
    // TapHandlers, which do not consume the press the way a MouseArea does, so
    // a full-window handler saw every click on the panel too -- approving a
    // permission or picking a model dismissed the sidebar out from under you.
    // Comparing the tap position against the panel's rectangle cannot be fooled
    // by whatever handler happened to be on top.
    Item {
        anchors.fill: parent

        TapHandler {
            onTapped: (point) => {
                const pt = point.scenePosition;
                const inPanel = pt.x >= panel.x && pt.x <= panel.x + panel.width
                             && pt.y >= panel.y && pt.y <= panel.y + panel.height;
                if (!inPanel) {
                    root.close();
                    return;
                }
                // Inside the panel but outside an open dropdown: close the
                // dropdown only, the way every other menu behaves.
                if (picker.open) {
                    const inPicker = pt.x >= panel.x + picker.x
                                  && pt.x <= panel.x + picker.x + picker.width
                                  && pt.y >= panel.y + picker.y
                                  && pt.y <= panel.y + picker.y + picker.height;
                    // ...but never the click that just opened it. This handler
                    // sees the same tap as the model row's, so without this the
                    // menu opened and shut on one click and looked dead.
                    const t = modelRow.mapToItem(null, 0, 0);
                    const inTrigger = pt.x >= t.x && pt.x <= t.x + modelRow.width
                                   && pt.y >= t.y && pt.y <= t.y + modelRow.height;
                    if (!inPicker && !inTrigger) picker.open = false;
                }
            }
        }
    }

    NeuSurface {
        id: panel

        readonly property int margin: Theme.shadowLGap

        width: Math.min(460, root.width * 0.34)
        y: Theme.barHeight + margin
        height: root.height - y - margin

        // Off-screen by its own width plus the shadow reach, so nothing of it
        // is left peeking at the edge when closed.
        x: root.shown ? margin : -(width + margin * 2)
        Behavior on x {
            NumberAnimation { duration: Theme.defaultMs; easing.type: Easing.OutCubic }
        }

        mode: "raised"
        tier: "xl"
        radius: Theme.radiusL
        surface: Theme.neuBgCard

        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.baseMs } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.sizeL
            spacing: Theme.sizeS

            // ---- header ----------------------------------------------------
            RowLayout {
                id: head
                Layout.fillWidth: true
                spacing: Theme.sizeS

                Text {
                    text: Icons.robot
                    color: Theme.neuAccentText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontL
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "assistant"
                        color: Theme.neuText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontM
                        font.letterSpacing: Theme.trackingHeader
                    }

                    // What is actually answering, and whether it is there at
                    // all -- the endpoint lives on another box, so "nothing is
                    // happening" has to be distinguishable from "not running".
                    // Tapping it opens the picker: the box holds several models
                    // and LM Studio loads whichever one a request names.
                    RowLayout {
                        id: modelRow

                        Layout.fillWidth: true
                        spacing: Theme.sizeXs

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (Llm.reach === "down")
                                    return Llm.reachNote + " · " + root.where;
                                if (Llm.model !== "") return Llm.model;
                                return Llm.reach === "up" ? "connected" : "checking…";
                            }
                            color: Llm.reach === "down" ? Theme.neuErrorText
                                 : (modelTap.hovered ? Theme.neuAccentText : Theme.neuTextDim)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: Theme.fastMs } }
                        }

                        Text {
                            visible: Llm.models.length > 0
                            text: Icons.chevronDown
                            color: modelTap.hovered ? Theme.neuAccentText : Theme.neuTextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                            rotation: picker.open ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: Theme.fastMs } }
                        }

                        HoverHandler { id: modelTap }
                        TapHandler {
                            onTapped: {
                                if (Llm.models.length === 0) Llm.probeNow();
                                picker.open = !picker.open;
                            }
                        }
                    }
                }

                BarLikeButton {
                    glyph: Icons.refresh
                    tip: "new conversation"
                    onActivated: Llm.reset()
                }

                // Ends the session and stops whatever the harness left running
                // -- opencode's server, in particular, which is deliberately
                // kept warm between messages.
                BarLikeButton {
                    glyph: Icons.power
                    tip: "end session"
                    tint: Theme.neuTextDim
                    onActivated: Llm.endSession()
                }

                BarLikeButton {
                    glyph: Icons.times
                    tip: "close"
                    onActivated: root.close()
                }
            }

            NeuDivider { Layout.fillWidth: true }

            // ---- transcript ------------------------------------------------
            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.sizeS
                model: Llm.chat

                // Stay pinned to the newest text while it streams, but only if
                // the reader has not scrolled up to look at something.
                property bool stick: true
                onMovementEnded: stick = atYEnd
                onCountChanged: if (stick) Qt.callLater(positionViewAtEnd)
                onContentHeightChanged: if (stick) Qt.callLater(positionViewAtEnd)

                delegate: Loader {
                    required property var model
                    required property int index

                    width: ListView.view.width
                    sourceComponent: model.kind === "approve" ? approvalCard
                                   : model.kind === "tool" ? toolCard : messageRow

                    Component {
                        id: messageRow
                        MessageRow {
                            kind: model.kind
                            text: model.text
                            reasoning: model.reasoning
                            stats: model.stats
                            done: model.done
                        }
                    }

                    Component {
                        id: approvalCard
                        ApprovalCard {
                            tool: model.tool
                            args: model.args
                            text: model.text
                            rowId: model.id
                            ok: model.ok
                            done: model.done
                        }
                    }

                    Component {
                        id: toolCard
                        ToolCard {
                            tool: model.tool
                            args: model.args
                            text: model.text
                            ok: model.ok
                            done: model.done
                        }
                    }
                }

                // The empty state doubles as the setup instructions, because
                // the most likely reason this panel is empty is that the file
                // it needs has not been written yet.
                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - Theme.sizeXl
                    spacing: Theme.sizeS
                    visible: Llm.chat.count === 0

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Llm.reach === "down" ? "no endpoint" : "ask it something"
                        color: Theme.neuTextMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontM
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: Llm.reach === "down"
                            ? "Point ~/.config/neu/llm.env at LM Studio\n(template: bin/neu-llm.env.example)"
                            : "It can read ~/dev and ~/.config, search with\nripgrep, read git state and this machine's sensors."
                        color: Theme.neuTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXs
                    }
                }
            }

            // ---- composer --------------------------------------------------
            NeuSurface {
                Layout.fillWidth: true
                implicitHeight: Math.max(44, input.implicitHeight + Theme.sizeM * 2)

                mode: "inset"
                tier: "s"
                radius: Theme.radiusM
                surface: Theme.neuBgComponent

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.sizeM
                    anchors.rightMargin: Theme.sizeM
                    spacing: Theme.sizeS

                    TextEdit {
                        id: input

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        // Enough for a whole alert handed over by the glance
                        // (about eight lines) before it scrolls; past that the
                        // transcript matters more than the draft.
                        Layout.maximumHeight: Theme.fontM * 11
                        color: Theme.neuText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontM
                        selectionColor: Theme.neuAccent
                        wrapMode: TextEdit.Wrap
                        clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: Llm.busy ? "thinking…" : "ask…"
                            color: Theme.neuTextDim
                            font: input.font
                        }

                        function submit() {
                            const body = text.trim();
                            if (body === "" || Llm.busy) return;
                            Llm.send(body);
                            text = "";
                        }

                        Keys.onEscapePressed: root.close()
                        // Shift+Tab holds the permission gate open or lets it
                        // shut -- the same reflex as clearing notifications one
                        // panel over, on the toggle that matters most here.
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Backtab
                                || (event.key === Qt.Key_Tab
                                    && (event.modifiers & Qt.ShiftModifier))) {
                                Llm.autoApprove = !Llm.autoApprove;
                                event.accepted = true;
                            }
                        }
                        // Enter sends, Shift+Enter is a newline -- the way every
                        // chat box works, and the reason this is a TextEdit.
                        Keys.onReturnPressed: (e) => {
                            if (e.modifiers & Qt.ShiftModifier) e.accepted = false;
                            else submit();
                        }
                        Keys.onEnterPressed: (e) => {
                            if (e.modifiers & Qt.ShiftModifier) e.accepted = false;
                            else submit();
                        }
                    }

                    BarLikeButton {
                        glyph: Llm.busy ? Icons.times : Icons.chevronRight
                        tint: Llm.busy ? Theme.neuErrorText : Theme.neuAccentText
                        tip: Llm.busy ? "stop" : "send"
                        onActivated: Llm.busy ? Llm.cancel() : input.submit()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sizeS

                // Auto-approve. Amber rather than accent when it is on: this is
                // a guard being held open, not a feature being enjoyed, and the
                // colour should say so every time you glance at the panel.
                Item {
                    implicitWidth: autoRow.implicitWidth
                    implicitHeight: 18

                    RowLayout {
                        id: autoRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.sizeXs

                        // raised = pressable, inset = held: the grammar in
                        // NeuSurface, applied to a checkbox. The catch is that
                        // an inset tier needs room to cast its shadows -- at
                        // 13px the xs offset and blur had nowhere to land and
                        // the checked state read as a flat dead square, which
                        // is the one thing flat is reserved to mean. 16px is
                        // the smallest box where "held" is legible.
                        NeuSurface {
                            implicitWidth: 16
                            implicitHeight: 16
                            mode: Llm.autoApprove ? "inset" : "raised"
                            tier: "xs"
                            radius: Math.round(Theme.radiusS / 2)
                            surface: Llm.autoApprove ? Theme.neuBg : Theme.neuBgComponent
                            // The well glows amber while the gate is open, the
                            // same signal the label and the bar glyph carry.
                            glow: Llm.autoApprove ? Theme.neuWarning : "transparent"
                            glowBlur: Theme.sizeXs

                            Text {
                                anchors.centerIn: parent
                                visible: Llm.autoApprove
                                text: Icons.check
                                color: Theme.neuWarningText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontXs
                            }
                        }

                        Text {
                            text: "auto-approve"
                            color: Llm.autoApprove ? Theme.neuWarningText
                                 : (autoHover.hovered ? Theme.neuTextMuted : Theme.neuTextDim)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                            Behavior on color { ColorAnimation { duration: Theme.fastMs } }
                        }
                    }

                    HoverHandler { id: autoHover }
                    TapHandler { onTapped: Llm.autoApprove = !Llm.autoApprove }
                }

                Text {
                    Layout.fillWidth: true
                    text: Llm.autoApprove ? "every request is granted"
                         : Llm.warming ? "waiting — a cold model loads first"
                         : Llm.busy ? "streaming — esc closes, the turn keeps going"
                                    : "enter sends · shift+enter newline"
                    color: Llm.autoApprove ? Theme.neuWarningText : Theme.neuTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ---- model picker ------------------------------------------------------
    // An overlay rather than a row in the column: the transcript should not
    // jump down every time you glance at which model is answering.
    NeuSurface {
        id: picker

        property bool open: false

        parent: panel
        x: Theme.sizeL
        y: Theme.sizeL + head.height + Theme.sizeS
        width: panel.width - Theme.sizeL * 2
        implicitHeight: models.implicitHeight + Theme.sizeS * 2
        z: Theme.zDropdown

        visible: open && root.shown
        mode: "raised"
        tier: "m"
        radius: Theme.radiusM
        surface: Theme.neuBgComponent



        ColumnLayout {
            id: models
            anchors.fill: parent
            anchors.margins: Theme.sizeS
            spacing: 2

            // ---- which agent, before which model -------------------------
            // The harness decides what the model is allowed to do; the model
            // only decides how well. So it is the first choice on the menu.
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sizeS
                text: "harness"
                color: Theme.neuTextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                font.letterSpacing: Theme.trackingSection
            }

            Repeater {
                model: Llm.harnesses

                delegate: Item {
                    id: hrow

                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 30

                    readonly property bool current: hrow.modelData.id === Llm.harness
                    readonly property bool usable: !!hrow.modelData.available

                    NeuSurface {
                        anchors.fill: parent
                        visible: hrow.current || hHover.hovered
                        mode: hrow.current ? "inset" : "flat"
                        tier: "xs"
                        radius: Theme.radiusS
                        surface: hrow.current ? Theme.neuBg : Theme.neuHoverHighlight
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sizeS
                        anchors.rightMargin: Theme.sizeS
                        spacing: Theme.sizeS

                        Text {
                            text: hrow.current ? Icons.check
                                : (hrow.usable ? Icons.terminal : Icons.times)
                            color: hrow.current ? Theme.neuAccentText
                                 : (hrow.usable ? Theme.neuTextMuted : Theme.neuTextDim)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontS
                        }

                        Text {
                            Layout.fillWidth: true
                            text: hrow.modelData.name
                            color: hrow.usable ? (hrow.current ? Theme.neuText : Theme.neuTextMuted)
                                               : Theme.neuTextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                        }

                        // An absent harness still earns a row: it is how you
                        // find out the thing exists and what installs it.
                        Text {
                            text: hrow.usable ? hrow.modelData.version : "not installed"
                            color: Theme.neuTextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                        }
                    }

                    HoverHandler { id: hHover }
                    TapHandler {
                        onTapped: {
                            if (!hrow.usable) return;   // nothing to switch to
                            Llm.selectHarness(hrow.modelData.id);
                            picker.open = false;
                        }
                    }
                }
            }

            NeuDivider { Layout.fillWidth: true }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sizeS
                text: "model"
                color: Theme.neuTextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                font.letterSpacing: Theme.trackingSection
            }

            Repeater {
                model: Llm.models

                delegate: Item {
                    id: opt

                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 34

                    readonly property bool current: opt.modelData.id === Llm.model
                    // "loaded" answers at once; anything else pays for a load
                    // first, which for a 120b is a minute you should expect.
                    readonly property bool hot: opt.modelData.state === "loaded"
                                             || opt.modelData.state === "loading"

                    NeuSurface {
                        anchors.fill: parent
                        visible: opt.current || rowHover.hovered
                        mode: opt.current ? "inset" : "flat"
                        tier: "xs"
                        radius: Theme.radiusS
                        surface: opt.current ? Theme.neuBg : Theme.neuHoverHighlight
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sizeS
                        anchors.rightMargin: Theme.sizeS
                        spacing: Theme.sizeS

                        Text {
                            text: opt.current ? Icons.check : (opt.hot ? Icons.fire : Icons.moon)
                            color: opt.current ? Theme.neuAccentText
                                 : (opt.hot ? Theme.neuWarningText : Theme.neuTextDim)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontS
                        }

                        Text {
                            Layout.fillWidth: true
                            text: opt.modelData.id
                            color: opt.current ? Theme.neuText : Theme.neuTextMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: opt.modelData.ctx > 0
                            text: Math.round(opt.modelData.ctx / 1024) + "k"
                            color: Theme.neuTextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                        }
                    }

                    HoverHandler { id: rowHover }
                    TapHandler {
                        onTapped: {
                            Llm.selectModel(opt.modelData.id);
                            picker.open = false;
                        }
                    }
                }
            }
        }
    }

    // A header glyph that lights on hover. BarButton lives in the bar module
    // and is sized for the bar; this is the same idea at panel scale.
    component BarLikeButton: Item {
        property string glyph: ""
        property string tip: ""
        property color tint: Theme.neuTextMuted

        signal activated()

        implicitWidth: 24
        implicitHeight: 24

        NeuSurface {
            anchors.fill: parent
            visible: hover.hovered
            mode: "raised"
            tier: "xs"
            radius: Theme.radiusS
            surface: Theme.neuHoverHighlight
        }

        Text {
            anchors.centerIn: parent
            text: parent.glyph
            color: hover.hovered ? Theme.neuAccentText : parent.tint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontM
            Behavior on color { ColorAnimation { duration: Theme.fastMs } }
        }

        HoverHandler { id: hover }
        TapHandler { onTapped: parent.activated() }
    }
}
