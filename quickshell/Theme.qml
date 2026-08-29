pragma Singleton

import QtQuick
import Quickshell

// Catppuccin Mocha, kept in sync with waybar/mocha.css so the panel and the
// bar never drift apart. Accent pair is the same pink->purple used by the
// hyprlock input field and the waybar box.
Singleton {
    readonly property color rosewater: "#f5e0dc"
    readonly property color flamingo: "#f2cdcd"
    readonly property color pink: "#f5c2e7"
    readonly property color mauve: "#cba6f7"
    readonly property color red: "#f38ba8"
    readonly property color maroon: "#eba0ac"
    readonly property color peach: "#fab387"
    readonly property color yellow: "#f9e2af"
    readonly property color green: "#a6e3a1"
    readonly property color teal: "#94e2d5"
    readonly property color sky: "#89dceb"
    readonly property color sapphire: "#74c7ec"
    readonly property color blue: "#89b4fa"
    readonly property color lavender: "#b4befe"
    readonly property color text: "#cdd6f4"
    readonly property color subtext1: "#bac2de"
    readonly property color subtext0: "#a6adc8"
    readonly property color overlay2: "#9399b2"
    readonly property color overlay1: "#7f849c"
    readonly property color overlay0: "#6c7086"
    readonly property color surface2: "#585b70"
    readonly property color surface1: "#45475a"
    readonly property color surface0: "#313244"
    readonly property color base: "#1e1e2e"
    readonly property color mantle: "#181825"
    readonly property color crust: "#11111b"

    readonly property color lightestPrimary: "#edd8f3"
    readonly property color lightPrimary: "#c88bda"
    readonly property color primary: "#ac4fc6"
    readonly property color darkPrimary: "#622574"
    readonly property color lightestSecondary: "#ffcce5"
    readonly property color lightSecondary: "#ff66b2"
    readonly property color secondary: "#ff007f"
    readonly property color darkSecondary: "#99004c"

    // Near-opaque on purpose. Hyprland's Lua parser rejects `hyprctl keyword`,
    // so a `layerrule = blur` for this namespace cannot be applied at runtime;
    // without blur behind it, a translucent panel just shows scrambled text
    // from whatever is underneath.
    readonly property color panelBg: Qt.rgba(base.r, base.g, base.b, 0.985)
    readonly property color rowBg: Qt.rgba(surface0.r, surface0.g, surface0.b, 0.85)
    readonly property color rowHover: Qt.rgba(overlay0.r, overlay0.g, overlay0.b, 0.85)

    readonly property string fontFamily: "UbuntuMonoNerdFont"
    readonly property int fontSize: 15
    readonly property int fontSizeSmall: 13
    readonly property int fontSizeHeader: 17

    readonly property int padding: 12
    readonly property int radius: 8
    readonly property int rowHeight: 30
    readonly property int animDuration: 180
}
