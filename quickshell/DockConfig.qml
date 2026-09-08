pragma Singleton

import QtQuick
import Quickshell

// The pinned app list behind the bar's Shortcuts row. Hand-edited -- this is a
// preference, not a design token, so it is deliberately NOT generated from
// theme/tokens.json. (Named for the auto-hiding dock it used to also feed; the
// dock is gone, the pin list outlived it.)
//
// `wmClass` is matched against the Hyprland window class to light the running
// dot; run `hyprctl clients -j | jq -r '.[].class'` to find one.
//
// `hotkey` is the bind that launches the same app, shown in the hover tooltip.
// It is written out here rather than discovered, because the Lua config format
// makes it undiscoverable: `hyprctl binds -j` reports all 65 binds as
// dispatcher "__lua" with no argument, so nothing at runtime can say which bind
// runs which command. That means this column CAN drift from hypr/hyprland.lua
// -- move a bind, move it here too. An app with no bind simply has no hotkey;
// Code is the one that does not.
Singleton {
    readonly property var pinned: [
        { name: "Terminal",  icon: Icons.terminal,  exec: "ghostty",                            wmClass: "com.mitchellh.ghostty", hotkey: "SUPER+Q" },
        { name: "LibreWolf", icon: Icons.firefox,   exec: "librewolf",                          wmClass: "librewolf", hotkey: "SUPER+F" },
        { name: "Chromium",  icon: Icons.chrome,    exec: "chromium",                           wmClass: "chromium", hotkey: "SUPER+W" },
        { name: "Files",     icon: Icons.files,     exec: "dolphin",                            wmClass: "org.kde.dolphin", hotkey: "SUPER+E" },
        { name: "Code",      icon: Icons.code,      exec: "code-oss",                           wmClass: "code-oss" },
        { name: "FreeTube",  icon: Icons.video,     exec: "flatpak run io.freetubeapp.FreeTube", wmClass: "FreeTube", hotkey: "SUPER+G" },
        { name: "SQLite",    icon: Icons.database,  exec: "sqlitebrowser",                      wmClass: "sqlitebrowser", hotkey: "SUPER+D" },
        { name: "Clipboard", icon: Icons.clipboard, exec: "copyq toggle",                       wmClass: "com.github.hluk.copyq", hotkey: "SUPER+V" }
    ]
}
