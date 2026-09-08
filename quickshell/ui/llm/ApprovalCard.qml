import QtQuick
import QtQuick.Layouts
import qs
import qs.ui.neu
import qs.services

// A tool asking permission, in the transcript rather than in a modal.
//
// A modal would cover the reasoning that led here, which is the one thing you
// need to judge the request. So it sits inline: what is being asked, the diff
// or command it wants to run, and two buttons. Nothing happens until one is
// pressed -- the harness is blocked on stdin, waiting -- and after 180 seconds
// silence is taken as no.
Item {
    id: root

    required property string tool
    required property string args
    required property string text
    required property string rowId
    required property bool ok
    required property bool done

    implicitHeight: card.implicitHeight
    implicitWidth: parent ? parent.width : 0

    NeuSurface {
        id: card
        width: parent.width
        implicitHeight: col.implicitHeight + Theme.sizeM * 2

        mode: root.done ? "flat" : "raised"
        tier: root.done ? "xs" : "s"
        radius: Theme.radiusS
        surface: Theme.neuBgCard
        // Pending permission is the only thing in this panel that stops the
        // world, so it is the only thing that glows.
        glow: root.done ? "transparent" : Theme.neuWarning
        glowBlur: Theme.sizeS

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.sizeM
            spacing: Theme.sizeS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sizeXs

                Text {
                    text: root.done ? (root.ok ? Icons.check : Icons.times) : Icons.warning
                    color: root.done ? (root.ok ? Theme.neuSuccessText : Theme.neuTextDim)
                                     : Theme.neuWarningText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontM
                }

                Text {
                    Layout.fillWidth: true
                    text: root.done ? root.text : "permission needed"
                    color: root.done ? Theme.neuTextDim : Theme.neuWarningText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    font.letterSpacing: Theme.trackingGroup
                    elide: Text.ElideRight
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.tool
                color: Theme.neuText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontM
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                visible: root.args !== "" && root.args !== root.tool
                text: root.args
                color: Theme.neuTextMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                wrapMode: Text.Wrap
                elide: Text.ElideMiddle
                maximumLineCount: 2
            }

            // The diff or the command. Capped, because a card that grows to
            // three hundred lines stops being something you can act on.
            NeuSurface {
                Layout.fillWidth: true
                visible: root.text !== "" && !root.done
                implicitHeight: Math.min(preview.implicitHeight + Theme.sizeS * 2, 180)
                mode: "inset"
                tier: "xs"
                radius: Theme.radiusS
                surface: Theme.neuBg

                Flickable {
                    anchors.fill: parent
                    anchors.margins: Theme.sizeS
                    contentWidth: preview.implicitWidth
                    contentHeight: preview.implicitHeight
                    clip: true

                    Text {
                        id: preview
                        text: root.text
                        color: Theme.neuTextMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXs
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !root.done
                spacing: Theme.sizeS

                Item { Layout.fillWidth: true }

                NeuButton {
                    text: "deny"
                    tint: Theme.neuTextMuted
                    flat: true
                    onClicked: Llm.approve(root.rowId, false)
                }

                NeuButton {
                    text: "approve"
                    tint: Theme.neuAccentText
                    onClicked: Llm.approve(root.rowId, true)
                }
            }
        }
    }
}
