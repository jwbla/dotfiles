pragma Singleton

import QtQuick
import Quickshell

// The one place that talks to Hyprland's dispatcher.
//
// Hyprland picks its config LANGUAGE at startup, and this session starts from
// `hypr/hyprland.lua`. That is not a cosmetic choice: `hyprctl dispatch <thing>`
// is no longer parsed as the classic keyword syntax at all. It gets wrapped as
// `hl.dispatch(<thing>)` and handed to Lua, so every plain dispatch string the
// shell was sending died at the socket as a syntax error:
//
//   $ hyprctl dispatch exec ghostty
//   error: [string "return hl.dispatch(exec ghostty)"]:1: ')' expected near 'ghostty'
//   $ hyprctl dispatch focuswindow address:0x557fa85531e0
//   error: [string "return hl.dispatch(focuswindow address:0x557f..."]:1: ')' expected near 'address'
//
// Which is why launching from the bar shortcuts did nothing, and why alt-tab
// could not actually move focus. The argument has to be a Lua *expression* that
// evaluates to a dispatcher -- the same `hl.dsp.*` calls hyprland.lua binds keys
// to. Everything funnels through here so no caller composes a dispatch string
// again; if this box is ever moved back to a .conf session, this file is the
// only one that has to learn the old syntax.
Singleton {
    id: root

    /** Quote a value as a Lua string literal. */
    function lit(s) {
        return "'" + String(s).replace(/\\/g, "\\\\").replace(/'/g, "\\'") + "'";
    }

    // execDetached rather than a Process: these fire from taps that can overlap,
    // and a single reused Process would drop whichever call landed second.
    function send(expr) {
        Quickshell.execDetached(["hyprctl", "dispatch", expr]);
    }

    /** Run a command. Goes through a shell, so `~` and quotes behave. */
    function exec(cmd) {
        send("hl.dsp.exec_cmd(" + lit(cmd) + ")");
    }

    /** Focus a window by address. Follows it to its workspace if it is elsewhere. */
    function focusWindow(addr) {
        send("hl.dsp.focus({ window = " + lit("address:" + addr) + " })");
    }

    /**
     * Go to a workspace. Numeric ids go through as numbers, the way hyprland.lua
     * writes them; names and relative forms ("e+1", "special:magic") as strings.
     */
    function workspace(id) {
        const n = /^-?\d+$/.test(String(id)) ? String(id) : lit(id);
        send("hl.dsp.focus({ workspace = " + n + " })");
    }

    /** Reload the compositor config. Its own hyprctl verb, not a dispatch. */
    function reload() {
        Quickshell.execDetached(["hyprctl", "reload"]);
    }
}
