import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.services
import qs.ui.neu

// One remembered notification.
//
// Deliberately the toast's own anatomy at a smaller tier -- the urgency rail on
// the left, icon, summary, body, app name in tracked caps -- so a row reads as
// "that thing that flew past" rather than as a log line about it. What is added
// is the part a toast cannot have: when it happened, how many times, and whether
// it has been seen.
NeuSurface {
    id: root

    required property var entry

    property bool expanded: false

    signal dismissed()

    readonly property int urgency: entry.urgency

    // Same rail tinting as Toast.qml -- one urgency, one colour, both places.
    readonly property color rail: urgency === NotificationUrgency.Critical
        ? Theme.neuErrorText
        : urgency === NotificationUrgency.Low ? Theme.neuTextDim : Theme.neuAccentText

    mode: "raised"
    tier: hover.hovered ? "s" : "xs"
    radius: Theme.radiusM
    surface: hover.hovered ? Theme.neuHoverHighlight : Theme.neuBgComponent

    // Read rows recede rather than disappear: the history is still the record.
    opacity: entry.read ? 0.62 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.fastMs } }

    implicitHeight: body.implicitHeight + Theme.sizeM * 2

    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        anchors.margins: 1
        width: Theme.borderL
        radius: Theme.borderL / 2
        color: root.rail
    }

    RowLayout {
        id: body
        anchors.fill: parent
        anchors.leftMargin: Theme.sizeL
        anchors.rightMargin: Theme.sizeS
        anchors.topMargin: Theme.sizeM
        anchors.bottomMargin: Theme.sizeM
        spacing: Theme.sizeM

        // appIcon is a NAME, not a path, so it has to go through the icon
        // provider; the `true` makes an unknown name yield "" instead of
        // logging, and the slot collapses. Same call Toast.qml makes.
        IconImage {
            readonly property string resolved: root.entry.appIcon
                ? Quickshell.iconPath(root.entry.appIcon, true) : ""

            visible: resolved !== ""
            source: resolved
            implicitSize: 24
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sizeS

                Text {
                    Layout.fillWidth: true
                    text: root.entry.summary
                    color: Theme.neuText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontM
                    font.weight: Theme.weightSemibold
                    elide: Text.ElideRight
                }

                // Unread dot. Rides next to the timestamp because that is where
                // the eye already goes to sort the list by recency.
                NeuBadge {
                    visible: !root.entry.read
                    dotOnly: true
                    tone: root.urgency === NotificationUrgency.Critical ? "error" : "accent"
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: Notifs.ago(root.entry.time)
                    color: Theme.neuTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.entry.body
                color: Theme.neuTextMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontS
                wrapMode: Text.WordWrap
                // Collapsed by default so a long body cannot push the rest of
                // the backlog off the panel; the row expands on click.
                maximumLineCount: root.expanded ? 40 : 2
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sizeS

                Text {
                    visible: root.entry.appName !== ""
                    text: root.entry.appName.toUpperCase()
                    color: Theme.neuTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    font.weight: Theme.weightSemibold
                    font.letterSpacing: Theme.fontXs * Theme.trackingHeader
                }

                // Repeats were folded into one row on the way in; say so, or the
                // count silently lies about how noisy something was.
                Text {
                    visible: root.entry.count > 1
                    text: "×" + root.entry.count
                    color: Theme.neuAccentText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    font.weight: Theme.weightSemibold
                }

                Item { Layout.fillWidth: true }
            }
        }

        // Dismiss this one. Only on hover -- a column of permanent × marks turns
        // the list into a form.
        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 20
            implicitHeight: 20
            opacity: hover.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fastMs } }

            Text {
                anchors.centerIn: parent
                text: Icons.times
                color: closeHover.hovered ? Theme.neuErrorText : Theme.neuTextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontS
            }

            HoverHandler { id: closeHover }

            TapHandler {
                onTapped: root.dismissed()
            }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.expanded = !root.expanded
    }
}
