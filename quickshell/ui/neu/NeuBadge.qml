import QtQuick
import qs

// .neu-badge -- a raised pill whose glow and text both derive from one tone,
// the `currentColor` trick from the web kit. `dotOnly` is .neu-badge--dot.
NeuSurface {
    id: root

    /** neutral | accent | success | warning | error | info */
    property string tone: "neutral"
    property string text: ""
    property bool dotOnly: false
    property bool pulse: false

    readonly property color toneColor: ({
        neutral: Theme.neuTextMuted,
        accent:  Theme.neuAccentText,
        success: Theme.neuSuccessText,
        warning: Theme.neuWarningText,
        error:   Theme.neuErrorText,
        info:    Theme.neuInfoText
    })[tone] || Theme.neuTextMuted

    readonly property color toneGlow: ({
        neutral: "transparent",
        accent:  Theme.neuAccent,
        success: Theme.neuSuccess,
        warning: Theme.neuWarning,
        error:   Theme.neuError,
        info:    Theme.neuInfo
    })[tone] || "transparent"

    mode: dotOnly ? "flat" : "raised"
    tier: dotOnly ? "xs" : "l"
    radius: dotOnly ? width / 2 : Theme.radiusL
    surface: dotOnly ? toneColor : Theme.neuBgComponent
    glow: dotOnly ? "transparent" : toneGlow

    implicitWidth: dotOnly ? 10 : (label.implicitWidth + Theme.sizeM * 2)
    implicitHeight: dotOnly ? 10 : (label.implicitHeight + Theme.sizeS)

    Text {
        id: label
        anchors.centerIn: parent
        visible: !root.dotOnly
        text: root.text
        color: root.toneColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontS
    }

    SequentialAnimation on opacity {
        running: root.pulse
        loops: Animation.Infinite
        NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0;  duration: 700; easing.type: Easing.InOutQuad }
    }
}
