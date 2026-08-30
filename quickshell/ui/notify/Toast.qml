import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.ui.neu

NeuSurface {
    id: root

    property var notification: null

    readonly property int urgency: notification ? notification.urgency : NotificationUrgency.Normal

    // The toast's left rail carries the urgency, exactly as
    // `border-left: 4px solid var(--neu-accent)` does in the web kit.
    readonly property color rail: urgency === NotificationUrgency.Critical
        ? Theme.neuErrorText
        : urgency === NotificationUrgency.Low ? Theme.neuTextDim : Theme.neuAccentText

    Layout.preferredWidth: Math.max(280, Math.min(420, body.implicitWidth + Theme.sizeL * 3))
    Layout.preferredHeight: Math.max(64, body.implicitHeight + Theme.sizeL * 2)

    mode: "raised"
    tier: "l"
    radius: Theme.radiusM
    surface: Theme.neuBgCard

    // neu-toast-slide-in: 0.35s ease-out
    opacity: 0
    x: 40
    Component.onCompleted: {
        opacity = 1;
        x = 0;
    }
    Behavior on opacity { NumberAnimation { duration: Theme.toastInMs; easing.type: Easing.OutCubic } }
    Behavior on x { NumberAnimation { duration: Theme.toastInMs; easing.type: Easing.OutCubic } }

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
        anchors.rightMargin: Theme.sizeM
        anchors.topMargin: Theme.sizeM
        anchors.bottomMargin: Theme.sizeM
        spacing: Theme.sizeM

        // A notification's appIcon is a NAME (`com.mitchellh.ghostty`), not a
        // path, so it has to go through the icon provider -- handing it to
        // IconImage raw makes it resolve relative to the QML module and fail.
        // The `true` asks for a lookup check, so an unknown name yields "" and
        // the slot collapses instead of logging.
        IconImage {
            readonly property string resolved: root.notification && root.notification.appIcon
                ? Quickshell.iconPath(root.notification.appIcon, true) : ""

            visible: resolved !== ""
            source: resolved
            implicitSize: 28
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.notification ? root.notification.summary : ""
                color: Theme.neuText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontM
                font.weight: Theme.weightSemibold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notification ? root.notification.body : ""
                color: Theme.neuTextMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontS
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Text {
                Layout.fillWidth: true
                visible: root.notification && root.notification.appName !== ""
                text: root.notification ? root.notification.appName.toUpperCase() : ""
                color: Theme.neuTextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                font.weight: Theme.weightSemibold
                font.letterSpacing: Theme.fontXs * Theme.trackingHeader
            }
        }

        // Close, wrapped in its countdown ring.
        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 22
            implicitHeight: 22

            Canvas {
                id: ring
                anchors.fill: parent
                property real progress: 1

                onProgressChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.beginPath();
                    ctx.strokeStyle = root.rail;
                    ctx.lineWidth = 2;
                    ctx.lineCap = "round";
                    ctx.arc(width / 2, height / 2, width / 2 - 2,
                            -Math.PI / 2, -Math.PI / 2 + progress * 2 * Math.PI);
                    ctx.stroke();
                }
            }

            Text {
                anchors.centerIn: parent
                text: Icons.times
                color: hover.hovered ? Theme.neuText : Theme.neuTextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontS
            }

            HoverHandler { id: hover }

            TapHandler {
                onTapped: if (root.notification) root.notification.dismiss()
            }
        }
    }

    // Critical notifications never time out, matching the dunst config they
    // replace (urgency_critical: timeout = 0).
    readonly property int lifespanMs: urgency === NotificationUrgency.Critical
        ? 0
        : (urgency === NotificationUrgency.Low ? 6000 : 8000)

    Timer {
        id: life
        interval: 50
        repeat: true
        running: root.lifespanMs > 0 && !hover.hovered
        property int elapsed: 0
        onTriggered: {
            elapsed += interval;
            ring.progress = 1 - elapsed / root.lifespanMs;
            if (elapsed >= root.lifespanMs && root.notification)
                root.notification.dismiss();
        }
    }
}
