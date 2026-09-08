import QtQuick
import qs
import qs.services
import qs.ui.neu

// The assistant's state, and the way back into it.
//
// The sidebar is usually closed, and the one thing that must not be invisible
// while it is closed is a tool waiting on permission: the turn is stopped dead
// until someone answers, and without this the only symptom is an assistant that
// went quiet. So a pending request turns the glyph amber and says "approve?" --
// the bar's job here is to make a blocked turn impossible to miss.
BarButton {
    id: root

    readonly property bool pending: Llm.pendingId !== ""
    readonly property bool unread: Llm.unread && !pending

    // The two states that want you also move. A blocked turn is the louder of
    // them -- it stops the assistant dead until you answer -- so it takes the
    // bare exclamation mark and the same cycle, rather than sitting amber and
    // static next to a bell that is also amber sometimes.
    readonly property bool cycling: pending || unread

    // An answer waiting to be read cycles through the wheel, starting at the
    // shell's own purple so the first thing you register is "that is the
    // assistant" and only then "and it is moving".
    //
    // Theme.rainbowMs had sat unused in the tokens since the theme was written;
    // this is its only consumer, so its value is tuned for exactly this job --
    // fast enough to catch the eye in passing, slow enough not to read as an
    // alarm. The loop runs ONLY while unread, so the compositor is not
    // repainting this glyph all day for decoration. Nothing else on the bar
    // does this: the bell keeps its fixed colours.
    property real cycle: 0

    // The accent's own position on the wheel: #8b2fe0 is hsl(271°, 74%, 53%).
    readonly property real accentHue: 0.753

    SequentialAnimation on cycle {
        running: root.cycling
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: Theme.rainbowMs }
    }

    icon: pending ? Icons.exclaim
        : Llm.reach === "down" ? Icons.times
        : Llm.busy ? Icons.hourglass
        : Icons.robot

    // A word only when the bar is asking YOU something. The hourglass already
    // says it is thinking; an ellipsis beside it says the same thing twice and
    // shifts the whole row's width while it does.
    label: pending ? "approve?" : ""

    // Colour is reserved for the two states that want you: amber when a turn is
    // blocked on your permission, the cycle when an answer is waiting unread.
    // Thinking is not one of those -- it stays the same grey as every other
    // module, and lets the hourglass carry the meaning on its own.
    tint: cycling ? Qt.hsla((accentHue + cycle) % 1.0, 0.74, 0.62, 1.0)
        : Llm.reach === "down" ? Theme.neuTextDim
        : Theme.neuTextMuted

    tip: pending ? "a tool is waiting for permission"
        : unread ? "an answer is waiting · SUPER+I"
        : Llm.reach === "down" ? "no endpoint · check ~/.config/neu/llm.env"
        : Llm.busy ? "thinking · " + (Llm.model || Llm.harness)
        : "assistant · SUPER+I"

    // The cycle drives the tint every frame; the smoothing Behavior would eat it.
    tintAnimated: !cycling

    active: Llm.panelOpen

    onActivated: root.requested()

    signal requested()

}
