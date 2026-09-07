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

    // Every model on the box: { id, type, state, ctx }. LM Studio will load one
    // on demand when a request names it, so the picker offers all of them and
    // marks which are already hot.
    property var models: []

    // True between "sent" and the first sign of life. A cold 120b spends that
    // whole time loading, and silence with no explanation reads as broken.
    property bool gotToken: false
    readonly property bool warming: busy && !gotToken
    property string reach: "unknown"   // unknown | up | down
    property string reachNote: ""

    // Index of the assistant row currently being streamed into, -1 between turns.
    property int streamRow: -1
    // tool call id -> row index, so a result can find the card its call made.
    property var toolRows: ({})

    signal appended()

    function send(text) {
        const body = (text || "").trim();
        if (body === "" || busy) return;
        chat.append(row("user", body));
        appended();
        streamRow = -1;
        toolRows = ({});
        busy = true;
        gotToken = false;
        // Named explicitly rather than left to the remembered file, so a pick
        // made a moment ago cannot lose a race with its own --select.
        turn.command = model !== ""
            ? ["neu-llm.py", "--stdin", "--conv", conv, "--model", model]
            : ["neu-llm.py", "--stdin", "--conv", conv];
        turn.stdinEnabled = true;
        turn.running = true;
        turn.write(body);
        turn.stdinEnabled = false;   // EOF: the script waits for it
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

    function reload() {
        chat.clear();
        streamRow = -1;
        history.running = true;
        probe.running = true;
    }

    function probeNow() { probe.running = true; }

    /** Switch models. Remembered across shell restarts by the script. */
    function selectModel(id) {
        if (id === "" || id === model) return;
        model = id;
        select.command = ["neu-llm.py", "--select", id];
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
            reach = "up";
            break;
        case "token":
            gotToken = true;
            grow("text", ev.v || "");
            break;
        case "reasoning":
            gotToken = true;
            grow("reasoning", ev.v || "");
            break;
        case "tool": {
            gotToken = true;
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
            break;
        case "done":
            if (streamRow >= 0) chat.setProperty(streamRow, "done", true);
            streamRow = -1;
            busy = false;
            break;
        case "probe":
            reach = ev.ok ? "up" : "down";
            endpoint = ev.endpoint || endpoint;
            if (ev.ok) {
                models = ev.models || [];
                reachNote = models.length + " models";
                if (ev.current) model = ev.current;
            } else {
                reachNote = ev.msg || "unreachable";
            }
            break;
        case "selected":
            model = ev.model || model;
            break;
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
                root.note("neu-llm.py exited " + code + " -- is it linked into ~/.local/bin?");
        }
    }

    Process {
        id: history
        command: ["neu-llm.py", "--history", "--conv", root.conv]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.parse(line)
        }
    }

    Process {
        id: probe
        command: ["neu-llm.py", "--probe"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.parse(line)
        }
        onExited: (code) => { if (code !== 0 && root.reach === "unknown") root.reach = "down"; }
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
        command: ["neu-llm.py", "--history", "--reset", "--conv", root.conv]
    }
}
