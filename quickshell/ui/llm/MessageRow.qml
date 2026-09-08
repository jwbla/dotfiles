import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.ui.neu

// One turn in the transcript.
//
// Model output is markdown, and markdown in a 440px column is mostly fine as
// long as fenced code is pulled out first: Text.MarkdownText will render a code
// block, but it wraps it, and wrapped code is unreadable. So the body is split
// on fences and each half gets the treatment it wants -- prose flows, code sits
// in an inset surface and scrolls sideways on its own.
Item {
    id: root

    required property string kind        // user | assistant | error
    required property string text
    required property string reasoning
    required property string stats
    required property bool done

    readonly property bool isUser: kind === "user"
    readonly property bool isError: kind === "error"

    implicitHeight: shell.implicitHeight
    // A message that has not started arriving yet still needs a caret's worth
    // of height, or the row pops into existence a beat after the spinner stops.
    implicitWidth: parent ? parent.width : 0

    // Splits the body into prose and code segments. An unterminated fence --
    // which is every fence while it is still streaming -- leaves an odd number
    // of parts, and treating that tail as code is exactly right: the block
    // renders as code from its first line rather than reflowing when it closes.
    function segments(src) {
        const out = [];
        const parts = (src || "").split("```");
        for (let i = 0; i < parts.length; i++) {
            const body = parts[i];
            if (i % 2 === 0) {
                if (body.trim() !== "")
                    out.push({ code: false, lang: "", body: body });
            } else {
                const nl = body.indexOf("\n");
                out.push({
                    code: true,
                    lang: nl > 0 ? body.slice(0, nl).trim() : "",
                    body: (nl >= 0 ? body.slice(nl + 1) : body).replace(/\n+$/, "")
                });
            }
        }
        return out;
    }

    NeuSurface {
        id: shell
        width: parent.width
        implicitHeight: col.implicitHeight + Theme.sizeM * 2

        // The neu story again: what you said is held (inset), what the machine
        // said is a card sitting on the surface (raised).
        mode: root.isUser ? "inset" : "flat"
        tier: "xs"
        radius: Theme.radiusS
        surface: root.isUser ? Theme.neuBgComponent
                             : (root.isError ? Theme.neuBgCard : "transparent")

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.sizeM
            spacing: Theme.sizeXs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sizeXs
                visible: !root.isUser

                Text {
                    text: root.isError ? Icons.warning : Icons.robot
                    color: root.isError ? Theme.neuErrorText : Theme.neuAccentText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontS
                }

                Text {
                    Layout.fillWidth: true
                    text: root.isError ? "error" : "assistant"
                    color: root.isError ? Theme.neuErrorText : Theme.neuTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    font.letterSpacing: Theme.trackingGroup
                }

                // The thinking, folded away. gpt-oss reasons at length and it is
                // occasionally the interesting half, but never the answer.
                Text {
                    visible: root.reasoning !== ""
                    text: think.expanded ? "hide thinking" : "thinking"
                    color: Theme.neuTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs

                    TapHandler { onTapped: think.expanded = !think.expanded }
                }
            }

            Text {
                id: think
                property bool expanded: false

                Layout.fillWidth: true
                visible: root.reasoning !== "" && expanded
                text: root.reasoning
                color: Theme.neuTextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                font.italic: true
                wrapMode: Text.Wrap
            }

            Repeater {
                model: root.segments(root.text)

                delegate: Loader {
                    required property var modelData

                    Layout.fillWidth: true
                    sourceComponent: modelData.code ? codeBlock : prose

                    Component {
                        id: prose

                        Text {
                            text: modelData.body.trim()
                            color: root.isError ? Theme.neuErrorText : Theme.neuText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontM
                            wrapMode: Text.Wrap
                            textFormat: Text.MarkdownText
                            linkColor: Theme.neuAccentLighter
                            onLinkActivated: (url) => Quickshell.execDetached(["xdg-open", url])
                        }
                    }

                    Component {
                        id: codeBlock

                        NeuSurface {
                            implicitHeight: code.implicitHeight + Theme.sizeM * 2
                            mode: "inset"
                            tier: "xs"
                            radius: Theme.radiusS
                            surface: Theme.neuBg

                            Flickable {
                                anchors.fill: parent
                                anchors.margins: Theme.sizeS
                                contentWidth: code.implicitWidth
                                contentHeight: code.implicitHeight
                                clip: true
                                flickableDirection: Flickable.HorizontalFlick

                                TextEdit {
                                    id: code
                                    text: modelData.body
                                    readOnly: true
                                    selectByMouse: true
                                    color: Theme.neuTertiaryLighter
                                    selectionColor: Theme.neuAccent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontS
                                }
                            }

                            // Copy, because the whole point of code in a sidebar
                            // is that it ends up somewhere else.
                            Text {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Theme.sizeXs
                                text: copied.running ? Icons.check : Icons.clipboard
                                color: copied.running ? Theme.neuSuccessText : Theme.neuTextDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontS
                                opacity: hover.hovered || copied.running ? 1 : 0.35
                                Behavior on opacity { NumberAnimation { duration: Theme.fastMs } }

                                HoverHandler { id: hover }
                                TapHandler {
                                    onTapped: {
                                        code.selectAll();
                                        code.copy();
                                        code.deselect();
                                        copied.restart();
                                    }
                                }

                                Timer { id: copied; interval: Theme.slowMs * 2 }
                            }
                        }
                    }
                }
            }

            // What the answer cost. Dim and small: worth having, never worth
            // reading before the answer itself.
            Text {
                Layout.fillWidth: true
                visible: root.stats !== ""
                text: root.stats
                color: Theme.neuTextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                elide: Text.ElideRight
            }

            // The caret, while the sentence is still arriving.
            Text {
                visible: !root.done && root.text === ""
                text: "…"
                color: Theme.neuTextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontM
            }
        }
    }
}
