pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The sidebar's conversation, one turn at a time.
//
// Everything hard lives in bin/neu-llm.py -- SSE framing, tool-call assembly,
// the read-only filesystem sandbox -- and reaches us as one JSON object per
// line. This singleton is the transcript and the state machine around it:
// which row is currently growing, whether we are waiting, what went wrong.
//
// The prompt goes to the script over STDIN rather than argv, for the same
// reason neu-ntfy-subscribe.sh feeds curl over stdin: argv is world-readable
// in `ps`, and what you type here is nobody else's business.
Singleton {
    id: root

    // Transcript rows. `kind` is user | assistant | tool | error -- tool calls
    // are rows of their own rather than decorations on a message, so the panel
    // shows what was read at the moment it was read.
    property ListModel chat: ListModel {}

    property bool busy: false
    property string conv: "default"
    property string model: ""
    property string endpoint: ""

    // Which agent is answering: builtin | pi | opencode. The dispatcher decides
    // (bin/neu-llm-harness.sh); we only report it and offer the switch.
    property string harness: "builtin"
    property var harnesses: []

    // Every model on the box: { id, type, state, ctx }. LM Studio will load one
    // on demand when a request names it, so the picker offers all of them and
    // marks which are already hot.
    property var models: []

    // True once the menu has been used this session. Until then the panel does
    // not name a model at all and lets the harness follow whatever the box has
    // loaded -- naming a remembered one that is no longer resident is how you
    // get "failed to load gpt-oss-120b" while the header says gemma.
    property bool modelPinned: false

    // An answer landed while you were not looking. The bar carries this until
    // the panel opens -- the same contract the bell has with notifications,
    // except this one is a single flag: there is only ever one conversation.
    property bool unread: false

    // Whether the sidebar is on screen. The bar module reads it to light its
    // glyph, the way NotifModule follows the notification centre.
    property bool panelOpen: false

    // Answer permission requests automatically while this is on.
    //
    // Deliberately NOT persisted: it survives until the shell reloads and no
    // longer. A checkbox that quietly stays on across restarts is one you
    // forget you left on, and this one hands a local model your shell.
    property bool autoApprove: false

    // True between "sent" and the first sign of life. A cold 120b spends that
    // whole time loading, and silence with no explanation reads as broken.
    property bool gotToken: false
    readonly property bool warming: busy && !gotToken

    // Why the silence, when the harness knows. A cold model loading is only one
    // answer; behind the compute gateway the other is that something else holds
    // the card, and the two look identical from here. The script asks and says
    // so in one line -- empty whenever there is nothing to add, which is every
    // turn against a plain endpoint.
    property string waitNote: ""
    property string reach: "unknown"   // unknown | up | down
    property string reachNote: ""

    // Index of the assistant row currently being streamed into, -1 between turns.
    property int streamRow: -1
    // tool call id -> row index, so a result can find the card its call made.
    property var toolRows: ({})

    signal appended()

    /** Raised when something elsewhere in the shell wants the panel on screen,
     *  carrying text to drop into the composer. LlmPanel listens; the service
     *  itself has no idea a window exists. */
    signal summoned(string prefill)

    /** Open the sidebar with a question written but NOT sent.
     *
     * The glance hands alerts over this way, which is the point of having both
     * on one desktop -- the thing that says something is broken should be one
     * click from the thing that explains it. Prefilling rather than sending
     * keeps that click cheap: you can edit it, add what you already know, or
     * think better of it, and no tokens are spent deciding.
     */
    function compose(prompt) {
        summoned(prompt || "");
    }

    /** Open and send immediately. What the `ask` IPC verb uses. */
    function ask(prompt) {
        summoned("");
        send(prompt);
    }

    function send(text) {
        const body = (text || "").trim();
        if (body === "" || busy) return;
        chat.append(row("user", body));
        appended();
        streamRow = -1;
        toolRows = ({});
        busy = true;
        gotToken = false;
        waitNote = "";
        // Named explicitly rather than left to the remembered file, so a pick
        // made a moment ago cannot lose a race with its own --select.
        turn.command = (modelPinned && model !== "")
            ? ["neu-llm-harness.sh", "--panel", "--conv", conv, "--model", model]
            : ["neu-llm-harness.sh", "--panel", "--conv", conv];
        turn.stdinEnabled = true;
        turn.running = true;
        // The prompt is the first line; stdin then STAYS open, because a tool
        // that needs permission is asked for it mid-turn and the answer goes
        // back down the same pipe. Closing it here would hang the first write.
        turn.write(JSON.stringify({ prompt: body }) + "\n");
    }

    function cancel() {
        if (!turn.running) return;
        turn.signal(15);
        note("cancelled");
        busy = false;
    }

    function reset() {
        cancel();
        chat.clear();
        streamRow = -1;
        toolRows = ({});
        wipe.running = true;
    }

    /** Re-check the endpoint and the harness list. Never touches the transcript. */
    function refresh() {
        probe.running = true;
        detect.running = true;
    }

    /** Read the stored conversation back into an empty panel.
     *
     * Refuses to run mid-turn. The transcript IS the turn while it is in
     * flight: the harness only appends to the history file once a turn ends, so
     * clearing here lost the answer being streamed and -- far worse -- any
     * pending approval card, leaving the harness blocked on stdin waiting for
     * an answer that no longer had a button.
     */
    function reload() {
        if (busy) {
            refresh();
            return;
        }
        chat.clear();
        streamRow = -1;
        toolRows = ({});
        history.running = true;
        refresh();
    }

    function probeNow() { probe.running = true; }

    /** The newest request still waiting on a human, or "" when none is. */
    readonly property string pendingId: {
        for (var i = chat.count - 1; i >= 0; i--) {
            const r = chat.get(i);
            if (r.kind === "approve" && !r.done) return r.id;
        }
        return "";
    }

    /** Answer whatever is waiting -- for a keybind, a script, or the card. */
    function answerPending(ok) {
        if (pendingId !== "") approve(pendingId, ok);
    }

    /** Answer a pending permission request. Goes back up the turn's stdin. */
    function approve(id, ok, auto) {
        if (!turn.running) return;
        // `auto` rides along so the audit log can tell a human's yes from a
        // gate that was being held open. They are not the same event.
        turn.write(JSON.stringify({ id: id, approve: !!ok, auto: !!auto }) + "\n");
        for (var i = chat.count - 1; i >= 0; i--) {
            if (chat.get(i).kind === "approve" && chat.get(i).id === id) {
                chat.setProperty(i, "done", true);
                chat.setProperty(i, "ok", !!ok);
                chat.setProperty(i, "text", ok ? "approved" : "declined");
                break;
            }
        }
    }

    /** Tear the backend down: forget the session, stop anything we started.
     *
     * The harnesses differ in what that means -- the builtin holds only a file,
     * pi is a process per turn, opencode leaves a server running so the next
     * message does not pay its startup again. This is the one button that ends
     * all three, and it is why the opencode server being long-lived is fine.
     */
    function endSession() {
        cancel();
        chat.clear();
        streamRow = -1;
        toolRows = ({});
        ending.command = ["neu-llm-harness.sh", "--end-session", "--conv", conv];
        ending.running = true;
    }

    /** Switch harness. Takes effect on the next turn, like a model change. */
    function selectHarness(id) {
        if (id === "" || id === harness) return;
        harness = id;
        pickHarness.command = ["neu-llm-harness.sh", "--select-harness", id];
        pickHarness.running = true;
        detect.running = true;
    }

    /** Switch models. Remembered across shell restarts by the script. */
    function selectModel(id) {
        if (id === "" || id === model) return;
        model = id;
        modelPinned = true;   // an explicit choice outranks what is loaded
        select.command = ["neu-llm-harness.sh", "--select", id];
        select.running = true;
    }

    // ---- rows ----------------------------------------------------------

    // ListModel roles are fixed by the first append, so every row carries the
    // whole shape whether it needs it or not.
    function row(kind, text) {
        return {
            kind: kind,
            text: text || "",
            reasoning: "",
            tool: "",
            args: "",
            id: "",
            stats: "",
            ok: true,
            done: true
        };
    }

    function note(msg) {
        chat.append(row("error", msg));
        appended();
    }

    function ensureStream() {
        if (streamRow >= 0) return streamRow;
        chat.append(row("assistant", ""));
        streamRow = chat.count - 1;
        chat.setProperty(streamRow, "done", false);
        appended();
        return streamRow;
    }

    function grow(field, chunk) {
        const i = ensureStream();
        chat.setProperty(i, field, chat.get(i)[field] + chunk);
    }

    function handle(ev) {
        switch (ev.t) {
        case "start":
            model = ev.model || "";
            endpoint = ev.endpoint || "";
            harness = ev.harness || harness;
            reach = "up";
            break;
        case "wait":
            // The harness asked the gateway what is holding the card. This is
            // not an error and does not belong in the transcript -- it is the
            // status line's job to explain a pause and then stop mentioning it.
            waitNote = ev.msg || "";
            break;
        case "token":
            gotToken = true;
            waitNote = "";
            grow("text", ev.v || "");
            break;
        case "reasoning":
            gotToken = true;
            waitNote = "";
            grow("reasoning", ev.v || "");
            break;
        case "tool": {
            gotToken = true;
            waitNote = "";
            // A new tool call ends the current assistant row: whatever it says
            // next is a fresh thought informed by what the tool returned.
            if (streamRow >= 0) chat.setProperty(streamRow, "done", true);
            streamRow = -1;
            const args = ev.args ? JSON.stringify(ev.args).replace(/^\{|\}$/g, "") : "";
            chat.append(row("tool", ""));
            const i = chat.count - 1;
            chat.setProperty(i, "tool", ev.name || "tool");
            chat.setProperty(i, "args", args);
            chat.setProperty(i, "done", false);
            toolRows[ev.id] = i;
            appended();
            break;
        }
        case "tool_result": {
            const i = toolRows[ev.id];
            if (i === undefined) break;
            chat.setProperty(i, "done", true);
            chat.setProperty(i, "ok", !!ev.ok);
            chat.setProperty(i, "text", ev.summary || "");
            break;
        }
        case "error":
            if (streamRow >= 0) chat.setProperty(streamRow, "done", true);
            streamRow = -1;
            note(ev.msg || "unknown error");
            // A failure you did not see is still something to come back to.
            if (!panelOpen) unread = true;
            break;
        case "stats": {
            // Hang the cost on the answer it paid for, not on the panel: scroll
            // back a week and you can still see what that reply took.
            const secs = (ev.ms / 1000).toFixed(1) + "s";
            const bits = [secs];
            if (ev.ttft_ms !== undefined && ev.ttft_ms !== null && ev.ttft_ms > 0)
                bits.push((ev.ttft_ms / 1000).toFixed(1) + "s to first token");
            if (ev.output > 0)
                bits.push(ev.tps + " tok/s");
            if (ev.output > 0)
                bits.push(ev.output + (ev.exact ? "" : "~") + " out"
                          + (ev.input > 0 ? " · " + ev.input + " in" : ""));
            const line = bits.join(" · ");
            for (var k = chat.count - 1; k >= 0; k--) {
                if (chat.get(k).kind === "assistant") {
                    chat.setProperty(k, "stats", line);
                    break;
                }
            }
            break;
        }
        case "done":
            if (streamRow >= 0) chat.setProperty(streamRow, "done", true);
            streamRow = -1;
            busy = false;
            if (!panelOpen) unread = true;
            break;
        case "probe":
            reach = ev.ok ? "up" : "down";
            endpoint = ev.endpoint || endpoint;
            if (ev.ok) {
                models = ev.models || [];
                harness = ev.harness || harness;
                reachNote = models.length + " models";
                if (ev.current) model = ev.current;
            } else {
                reachNote = ev.msg || "unreachable";
            }
            break;
        case "selected":
            model = ev.model || model;
            break;
        case "harnesses":
            harnesses = ev.harnesses || [];
            harness = ev.active || harness;
            break;
        case "harness_selected":
            harness = ev.harness || harness;
            break;
        case "session_ended":
            note(ev.stopped ? "session ended, " + (ev.harness || "") + " server stopped"
                            : "session ended");
            break;
        case "approve": {
            // A tool wants permission. It is a row like any other so the
            // request sits in the conversation where it happened, not in a
            // modal that hides what led to it.
            if (streamRow >= 0) chat.setProperty(streamRow, "done", true);
            streamRow = -1;
            gotToken = true;
            chat.append(row("approve", ev.preview || ""));
            const i = chat.count - 1;
            chat.setProperty(i, "tool", ev.tool || ev.path || "write");
            chat.setProperty(i, "args", ev.path || "");
            chat.setProperty(i, "id", ev.id || "");
            chat.setProperty(i, "done", false);
            appended();
            // The card is appended first either way, so an auto-approved
            // request still leaves a record of what was asked and granted.
            if (autoApprove) {
                approve(ev.id || "", true, true);
                chat.setProperty(i, "text", "auto-approved");
            }
            break;
        }
        case "approve_timeout": {
            for (var j = chat.count - 1; j >= 0; j--) {
                if (chat.get(j).kind === "approve" && chat.get(j).id === ev.id) {
                    chat.setProperty(j, "done", true);
                    chat.setProperty(j, "ok", false);
                    chat.setProperty(j, "text", "timed out — treated as no");
                    break;
                }
            }
            break;
        }
        case "history":
            replay(ev.m);
            break;
        }
    }

    // A stored turn is an OpenAI message, not one of our rows: assistant rows
    // that only carried tool calls have empty content and would otherwise
    // reopen the transcript with a row of nothing.
    function replay(m) {
        if (!m || !m.role) return;
        if (m.role === "user") {
            chat.append(row("user", m.content || ""));
        } else if (m.role === "assistant") {
            if ((m.content || "").trim() !== "")
                chat.append(row("assistant", m.content));
        } else if (m.role === "tool") {
            chat.append(row("tool", ""));
            const i = chat.count - 1;
            chat.setProperty(i, "tool", m.name || "tool");
            chat.setProperty(i, "text", (m.content || "").split("\n")[0].slice(0, 160));
            chat.setProperty(i, "ok", !(m.content || "").startsWith("denied:"));
        }
        appended();
    }

    function parse(line) {
        const s = (line || "").trim();
        if (s === "") return;
        try {
            handle(JSON.parse(s));
        } catch (e) {
            console.warn("Llm: unparsable line:", s.slice(0, 120));
        }
    }

    // The bar carries this service's state whether or not the panel has ever
    // been opened, so the first look at the endpoint and the harness list has
    // to happen at startup -- not on first open. Otherwise the glyph spends the
    // session claiming "builtin, unknown" while the dispatcher runs something
    // else entirely.
    Component.onCompleted: refresh()

    // ---- processes -----------------------------------------------------

    Process {
        id: turn
        command: ["neu-llm.py", "--stdin", "--conv", root.conv]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.parse(line)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const t = (this.text || "").trim();
                if (t !== "") console.warn("neu-llm.py:", t);
            }
        }

        onExited: (code) => {
            root.busy = false;
            if (root.streamRow >= 0) {
                root.chat.setProperty(root.streamRow, "done", true);
                root.streamRow = -1;
            }
            // 130 is our own SIGTERM on cancel, and the script has already said
            // why for every failure it can describe. A bare non-zero here means
            // it never ran at all -- almost always "not on PATH yet".
            if (code !== 0 && code !== 130 && code !== 143 && root.chat.count === 0)
                root.note("the harness exited " + code
                          + " -- is neu-llm-harness.sh linked into ~/.local/bin?");
        }
    }

    Process {
        id: history
        command: ["neu-llm-harness.sh", "--history", "--conv", root.conv]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.parse(line)
        }
    }

    Process {
        id: probe
        command: ["neu-llm-harness.sh", "--probe"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.parse(line)
        }
        onExited: (code) => { if (code !== 0 && root.reach === "unknown") root.reach = "down"; }
    }

    Process {
        id: ending
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.parse(line)
        }
    }

    Process {
        id: detect
        command: ["neu-llm-harness.sh", "--detect"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.parse(line)
        }
    }

    Process {
        id: pickHarness
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.parse(line)
        }
    }

    Process {
        id: select
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.parse(line)
        }
    }

    Process {
        id: wipe
        command: ["neu-llm-harness.sh", "--history", "--reset", "--conv", root.conv]
    }
}
