import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import qs

// The whole design system in one component.
//
//   raised  two shadows -- dark at +offset (bottom-right), light at -offset
//           (top-left), blur = 2 x offset.  Reads as pressable.
//   inset   the same pair, cast inward.  Reads as active / held, or as a well.
//   flat    no shadow at all.  Reads as disabled.
//
// From src/guides/Foundations.mdx: "Neumorphism encodes affordance ... don't
// break that grammar for decoration." Pick `mode` for what the thing MEANS.
//
// `reach` exposes --neu-shadow-*-gap: lay siblings out that far apart and their
// shadows meet instead of piling up. Use it for spacing, not a guessed margin.
Item {
    id: root

    /** raised | inset | flat */
    property string mode: "raised"
    /** xxs | xs | s | m | l | xl  (inset understands xs | s | m | l) */
    property string tier: "m"

    property color surface: Theme.neuBgComponent
    property int radius: Theme.radiusM
    property bool disabled: false

    /** Optional accent glow, e.g. a focus ring or a status tint. */
    property color glow: "transparent"
    property int glowBlur: Theme.sizeS

    /** Optional hairline outline. Transparent by default, so it costs nothing
     *  until something asks for it -- a hover, a focus ring, a selected row. */
    property color outline: "transparent"
    property int outlineWidth: Theme.borderXs

    readonly property int reach: Neu.reach(tier)
    readonly property var _t: mode === "inset" ? Neu.insetTier(tier) : Neu.tier(tier)

    default property alias content: body.data

    opacity: disabled ? 0.5 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.fastMs } }

    // ---- raised: two outward shadows, drawn behind the face ---------------

    RectangularShadow {
        anchors.fill: parent
        visible: root.mode === "raised"
        offset: Qt.vector2d(root._t.o, root._t.o)
        blur: root._t.b
        radius: root.radius
        color: Theme.neuShadowDark
    }

    RectangularShadow {
        anchors.fill: parent
        visible: root.mode === "raised"
        offset: Qt.vector2d(-root._t.o, -root._t.o)
        blur: root._t.b
        radius: root.radius
        color: Theme.neuShadowLight
    }

    // Status / focus glow. --neu-badge--success and friends stack this on top of
    // the raised pair rather than replacing it.
    RectangularShadow {
        anchors.fill: parent
        visible: root.glow.a > 0
        offset: Qt.vector2d(0, 0)
        blur: root.glowBlur
        radius: root.radius
        color: root.glow
    }

    // ---- the face ---------------------------------------------------------

    Rectangle {
        id: face
        anchors.fill: parent
        radius: root.radius
        color: root.surface
        visible: root.mode !== "inset"
        Behavior on color { ColorAnimation { duration: Theme.fastMs } }
    }

    // ---- inset: the same pair cast inward ---------------------------------
    //
    // Two InnerShadows chained -- the first takes the bare shape, the second
    // takes the first's output, so the shape's alpha carries through and both
    // shadows land inside the same rounded rect.

    // layer.enabled is CONSTANT. Binding it to the mode looked like a saving --
    // no layer texture for a surface that is not inset -- but tearing the layer
    // down destroys the texture the InnerShadow chain below reads from, and the
    // chain never re-acquires it when the layer comes back. The practical
    // effect: any surface that went inset -> raised -> inset lost its well for
    // good, so one hover over a chip flattened it for the rest of the session.
    Rectangle {
        id: insetShape
        anchors.fill: parent
        radius: root.radius
        color: root.surface
        visible: false
        layer.enabled: true
    }

    // NOT cached. The source Rectangle's layer is torn down whenever `mode`
    // leaves "inset" -- which is every hover on a chip -- and a cached effect
    // does not re-render when that layer comes back. The well simply never
    // returned: hover a chip in the glance once and it stayed flat for the rest
    // of the session. These shapes are static, so Qt redraws them only when
    // something actually changes; the cache was buying nothing.
    InnerShadow {
        id: insetDark
        anchors.fill: parent
        visible: false
        source: insetShape
        color: Theme.neuShadowDark
        horizontalOffset: root._t.o
        verticalOffset: root._t.o
        radius: root._t.b
        samples: Math.min(33, root._t.b * 2 + 1)
    }

    InnerShadow {
        anchors.fill: parent
        visible: root.mode === "inset"
        source: insetDark
        color: Theme.neuShadowLight
        horizontalOffset: -root._t.o
        verticalOffset: -root._t.o
        radius: root._t.b
        samples: Math.min(33, root._t.b * 2 + 1)
    }

    // ---- outline ----------------------------------------------------------
    //
    // Above both the face and the inset chain, because it has to read the same
    // whichever of them drew the surface; below the children, because it is
    // only ever a hairline at the edge and content should sit on top of it.

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        visible: root.outline.a > 0
        border.width: root.outlineWidth
        border.color: root.outline
        Behavior on border.color { ColorAnimation { duration: Theme.fastMs } }
    }

    // ---- children ---------------------------------------------------------

    Item {
        id: body
        anchors.fill: parent
    }
}
