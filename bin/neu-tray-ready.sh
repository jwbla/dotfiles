#!/usr/bin/env bash
# Block until a StatusNotifier tray host exists, then let XDG autostart proceed.
#
# Tray clients are supposed to notice a watcher appearing later and re-register.
# Plenty do not -- they ask once, at startup, and if nobody is listening they
# simply never show an icon. Enpass is the case that prompted this: on this box
# it came up at 13:32:23 and quickshell claimed org.kde.StatusNotifierWatcher at
# 13:32:25, so the bar's tray sat empty all session with the app running happily
# behind it. Restarting Enpass afterwards populates the tray immediately, which
# is how the two-second race was identified.
#
# systemd starts XDG autostart entries from xdg-desktop-autostart.target; the
# drop-in in systemd/ orders that target after this unit.
#
# Bounded, and successful either way: if the shell never comes up, neu-shell.sh
# falls back to waybar (which provides its own watcher) and autostart still has
# to happen regardless. Waiting forever would cost the session its autostarts.
set -uo pipefail

TIMEOUT=${NEU_TRAY_TIMEOUT:-20}
deadline=$((SECONDS + TIMEOUT))

while (( SECONDS < deadline )); do
    if busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1; then
        exit 0
    fi
    sleep 0.25
done

echo "neu-tray-ready: no StatusNotifierWatcher after ${TIMEOUT}s; continuing" >&2
exit 0
