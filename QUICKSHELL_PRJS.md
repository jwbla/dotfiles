# Quickshell — Advanced Project Ideas

Ambitious-but-feasible Quickshell projects, tailored to this setup (Hyprland +
Waybar, ghostty/tmux, Taskwarrior/Timewarrior, dual-battery laptop, static
Catppuccin Mocha with a pink→purple accent `#ac4fc6`/`#ff007f`).

"Advanced" here = multi-component, stateful, and replacing a real chunk of the
stack rather than adding one widget. Every backend below is either a built-in
Quickshell module or a shell command already written in this repo, so the work
is QML/state, not new logic.

---

## Background: what you build on

Quickshell ships service modules so most data is a reactive binding, not a
parsed script:

- **Quickshell.Hyprland** — IPC dispatch + event stream, workspaces, monitors,
  toplevels, `GlobalShortcut`, `HyprlandFocusGrab` (click-outside dismiss).
- **Quickshell.Services** — `Mpris` (media + art), `Pipewire` (per-app volume,
  sinks/sources), `UPower` + `PowerProfiles`, `Notifications` (full daemon),
  `SystemTray`, `Pam` (lock auth), `Bluetooth`.
- **Quickshell.Wayland** — `WlSessionLock` (real lock surface), `ScreencopyView`
  (live window thumbnails), `ToplevelManager` (taskbars/overviews).
- **Quickshell.Io** — `Process`, `FileView` (watch files), `IpcHandler` (expose
  callable targets to keybinds/CLI), `JsonAdapter` (config persistence).
- **Quickshell core** — `PanelWindow`/`PopupWindow`, per-monitor `Variants`,
  `ColorQuantizer` (palette from image), `DesktopEntries` (app DB), hot-reload.

No built-in NetworkManager / brightness / weather service — those go through
`Process` (`nmcli`, `brightness.sh`, `weather.sh`), which is the main glue
pattern. Wrap each external tool in a "service singleton" so the UI stays
declarative.

---

## 1. Command Center — Taskwarrior + Timewarrior + tmux panel

**★ Highest fit.** A slide-out side panel (bind it to `SUPER+A`, replacing
`tmux-wofi.sh`) fusing the three things this workflow already orbits — the same
data already surfaced in the zsh `_motd` and the starship custom modules.

- **Tasks** — live `task due.before:+24h` + overdue, grouped by project,
  click-to-`done`, click-to-`start`, inline add-task input. Re-query on a
  `FileView` watch of `~/.task` or a `Process` exit.
- **Time** — current Timewarrior tag with a live-ticking elapsed timer,
  one-click start/stop/switch, today's total per tag.
- **tmux** — projects from `~/.config/tms/projects/*.conf` with the ● running /
  ○ stopped state from `tmux-session-manager.sh`; click to attach, reusing the
  existing ghostty-focus-via-hyprctl logic from `tmux-wofi.sh`.

**Feasible because** every data source is already a script in this repo;
Quickshell just wraps them in `Process`/`FileView`. Nothing off-the-shelf does
this — it's the most "you" project and the highest daily payoff.

---

## 2. Full bar replacement with interactive popups

Port Waybar, then do the things Waybar can't.

- **MPRIS now-playing** with album art, real seek scrubber, multi-player
  switching — native `Mpris`, no `playerctl --follow` script.
- **Dual-battery** widget with a popup: per-cell Wh, live drain rate (feed it
  `battery_profile.sh` output), estimated time-to-empty — richer than the
  current icon ramp.
- **Network / audio** click-to-open inline popups (wifi list via `nmcli`,
  per-app mixer via `Pipewire`) instead of launching `pavucontrol`.
- **Workspaces** via native Hyprland IPC, animated pink→purple glow done in QML
  shaders to match the current Waybar box.

**Feasible because** `Mpris`/`UPower`/`Pipewire`/`Hyprland` are built-in
bindings — effort is breadth, not depth. Migrate one module at a time while
Waybar still runs. This is the "this is why I switched" endgame; do it after the
smaller widgets prove the QML is comfortable.

---

## 3. Launcher + switcher framework (replace wofi entirely)

One launcher runtime with pluggable modes, replacing wofi + both jq/dmenu
scripts.

- `drun` app launcher (replaces `wofi --show drun`) via `DesktopEntries`.
- Window switcher — port `workspace_switcher.sh` (keep the hyprctl client logic,
  drop wofi).
- tmux project picker — port `tmux-wofi.sh`.
- Optional extra modes seen across the ecosystem: calculator (libqalculate),
  emoji picker, `>` command mode.
- Fuzzy filtering, custom-rendered rows, Catppuccin theme, animations wofi
  can't do.

**Feasible because** it's mostly existing shell logic behind a nicer reactive
list with a fuzzy filter. The novelty is the mode abstraction — good QML
practice.

---

## 4. Idle + lock + notification stack

Most ambitious — own the session surfaces. Fills the **idle gap** (no
hypridle/swayidle currently configured).

- **Idle manager** — dim → lock → DPMS-off escalation, with idle-inhibit while
  media plays.
- **Lock screen** replacing hyprlock — blurred screenshot, the gradient input
  field, clock, redone in QML on `WlSessionLock` + `Pam`.
- **Notification daemon** replacing dunst — native, MPRIS-aware, plus a
  notification center / history panel (which dunst doesn't give you).

**Feasible but hardest** — the `Idle`, session-lock, and notification-server
APIs are built in, but this stack owns security-sensitive surfaces. Attempt it
**last**, once the QML is trusted.

---

## 5. System-monitor dashboard

Seen in caelestia/end-4 as a tabbed dashboard; on-theme given the existing
`sysinfo.sh` and `battery_*.sh` scripts.

- "Tank" cards for CPU / RAM / disk / dual-battery, temperatures via
  `lm-sensors`, network throughput graphs.
- Reuse `sysinfo.sh --json` and the `battery_profile.sh` drain data as backends.
- Calendar + weather tab (the existing `weather.sh` dual-source OpenWeatherMap /
  wttr.in JSON feeds it directly), world clock, Pomodoro + stopwatch
  (consolidating the half-built `~/.config/waybar/pomodoro.sh`).

**Feasible because** the data scripts already exist and emit JSON; this is
layout + a few `Process` pollers behind it.

---

## 6. Quick-settings control center

Android-style quick-toggle grid + management dialogs, a pattern both big configs
implement.

- Toggle grid: WiFi, Bluetooth, night light (hyprsunset), idle inhibitor, mic
  mute, **power profiles** (`PowerProfiles`/power-profiles-daemon — natural on a
  laptop), game mode, dark mode.
- WiFi browser + connect dialog (`nmcli`); Bluetooth scan/pair (`Bluetooth`
  service); per-app Pipewire mixer + sink/source selector.
- Brightness slider wired to the existing `brightness.sh` (intel_backlight
  sysfs), with `ddcutil` for any external HDMI-A-1 monitor.

**Feasible because** it's mostly `Process` wrappers (`nmcli`, `brightnessctl`)
plus the built-in `Bluetooth`/`Pipewire`/`PowerProfiles` modules behind a toggle
grid.

---

## 7. AI sidebar assistant *(stretch / most ambitious)*

The flagship feature of end-4's config — a left-sidebar LLM chat.

- Pluggable providers (Anthropic/Claude, OpenAI, Ollama, OpenRouter), streaming
  responses, reasoning "think" blocks, syntax-highlighted code blocks.
- File/image attachment as context; optional web-search source citations.
- Hyprland `GlobalShortcut` to summon it; `IpcHandler` so a keybind or script
  can open it pre-filled.

**Feasible but the deepest** — streaming HTTP + markdown/code rendering in QML
is real work. Worth it only if a desktop LLM panel fits the workflow.

---

## Suggested sequence

A small warm-up first (a volume/brightness **OSD** — currently missing, since
`brightness.sh`/`pactl` change values silently), then:

`OSD` → **#1 Command Center** → **#2 Full bar** → #3 Launcher → #5/#6 dashboards
→ #4 session stack → #7 AI sidebar.

Each step is shippable on its own and runs **alongside** the existing
Waybar/wofi/dunst stack, so the desktop is never mid-broken.

---

## Architecture patterns worth copying

- **IPC-driven control** — `IpcHandler` + a thin CLI (the caelestia model) so
  Hyprland keybinds and scripts can toggle panels, lock, control mpris, set
  wallpaper.
- **Service singletons** — one QML singleton per external tool (`nmcli`,
  `brightness.sh`, `weather.sh`, recorder) so the UI stays declarative.
- **Lazy-loaded panels** — shared animation + input-region/exclusion-zone
  management with `FocusGrab` click-outside dismissal.
- **Stow-compatible packaging** — a `quickshell/` dir symlinked to
  `~/.config/quickshell` like the other packages; run with `qs -c quickshell`.

## Reference configs

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) — most
  feature-dense (AI sidebar, overview, quick-settings, cliphist, music
  recognition, Material You theming).
- [caelestia-dots/shell](https://github.com/caelestia-dots/shell) — morphing
  drawers, audio-reactive media, system-monitor dashboard, screen recorder, full
  QML settings app, IPC-via-CLI architecture.
- [doannc2212/quickshell-config](https://github.com/doannc2212/quickshell-config),
  [tripathiji1312/quickshell](https://github.com/tripathiji1312/quickshell),
  [bgibson72/yahr-quickshell](https://github.com/bgibson72/yahr-quickshell) —
  leaner, modular starting points.
- [Quickshell module docs](https://quickshell.org/docs/) ·
  [GitHub topic](https://github.com/topics/quickshell)
