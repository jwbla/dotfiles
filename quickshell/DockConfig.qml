pragma Singleton

import QtQuick
import Quickshell

// What sits in the dock. Hand-edited -- this is a preference, not a design token,
// so it is deliberately NOT generated from theme/tokens.json.
//
// `wmClass` is matched against the Hyprland window class to light the running
// dot; run `hyprctl clients -j | jq -r '.[].class'` to find one.
Singleton {
    readonly property var pinned: [
        { name: "Terminal",  icon: Icons.terminal,  exec: "ghostty",                            wmClass: "com.mitchellh.ghostty" },
        { name: "LibreWolf", icon: Icons.firefox,   exec: "librewolf",                          wmClass: "librewolf" },
        { name: "Chromium",  icon: Icons.chrome,    exec: "chromium",                           wmClass: "chromium" },
        { name: "Files",     icon: Icons.files,     exec: "dolphin",                            wmClass: "org.kde.dolphin" },
        { name: "FreeTube",  icon: Icons.video,     exec: "flatpak run io.freetubeapp.FreeTube", wmClass: "FreeTube" },
        { name: "SQLite",    icon: Icons.database,  exec: "sqlitebrowser",                      wmClass: "sqlitebrowser" },
        { name: "Clipboard", icon: Icons.clipboard, exec: "copyq toggle",                       wmClass: "com.github.hluk.copyq" }
    ]
}
