import QtQuick
import QtQuick.Layouts
import qs
import qs.ui.neu

// A tool call, inline in the transcript.
//
// It sits in the conversation rather than in a log because the point is to see
// what the model reached for at the moment it reached: "read_file ~/dev/x" is
// the difference between an answer you can trust and one you cannot. A refusal
// -- a path outside the roots, anything on the deny list -- shows red and stays
// visible; the sandbox is only reassuring if you can watch it work.
Item {
    id: root

    required property string tool
    required property string args
    required property string text
    required property bool ok
    required property bool done

    implicitHeight: card.implicitHeight
    implicitWidth: parent ? parent.width : 0

    readonly property string glyph: {
        switch (tool) {
        case "read_file": return Icons.files;
        case "list_dir": return Icons.folder;
        case "search_files": return Icons.search;
        case "git_info": return Icons.git;
        case "system_status": return Icons.cpu;
        default: return Icons.terminal;
        }
    }

    NeuSurface {
        id: card
        width: parent.width
        implicitHeight: row.implicitHeight + Theme.sizeS * 2

        mode: "inset"
        tier: "xs"
        radius: Theme.radiusS
        surface: Theme.neuBg

        RowLayout {
            id: row
            anchors.fill: parent
            anchors.leftMargin: Theme.sizeM
            anchors.rightMargin: Theme.sizeM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.sizeS

            Text {
                text: root.glyph
                color: root.done ? (root.ok ? Theme.neuTertiaryLight : Theme.neuErrorText)
                                 : Theme.neuTextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontM
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.tool + (root.args !== "" ? "  " + root.args : "")
                    color: Theme.neuTextMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.text !== ""
                    text: root.text
                    color: root.ok ? Theme.neuTextDim : Theme.neuErrorText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    elide: Text.ElideRight
                }
            }

            NeuSpinner {
                visible: !root.done
                font.pixelSize: Theme.fontS
                tint: Theme.neuAccentLight
            }

            Text {
                visible: root.done
                text: root.ok ? Icons.check : Icons.times
                color: root.ok ? Theme.neuSuccessText : Theme.neuErrorText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontS
            }
        }
    }
}
