# The neu desktop

This repo now wears **[`@rgtv/neu`](https://gitea.i.realgamers.tv/RealGamers/rgtv-ds)**, the
neumorphic design system in `~/dev/rgtv-ds`, across the whole desktop — shell, window manager,
lock screen, terminals, prompt, and GTK/Qt apps.

It is uncommitted work on `master`. **Everything here backs out**; §5 is the part to read first
if you are mid-test-drive and want out.

---

## 1. What it is

`@rgtv/neu` v3.1.0 already contains a picture of this machine: `src/demos6.stories.tsx` ships a
*NeuOS (Desktop)* story — a whole fake desktop OS built from the component library, whose lock
screen reads `JW` / `jwbla`. And `BITMAP_PIPELINE.md` lists the missing lane:

> | **Native** | its own draw API | tokens exported to the host's format | quickshell QML, JUCE `LookAndFeel`, Hyprland/waybar configs |

This is that lane. It also closes a loop: `rgtv-ds/src/theme/palette.css` says its Catppuccin
block was *"pulled verbatim from `~/dev/dotfiles/waybar/mocha.css`"*. The palette came from here;
now the whole system comes back.

### The one rule

From `src/guides/Foundations.mdx`:

> *"Neumorphism encodes affordance. Raised = pressable, inset = active/held, flat = disabled.
> Don't break that grammar for decoration."*

Depth comes from **shadow, not surface contrast** — the three surface levels are 4 values apart
(`#141414` → `#171717` → `#181818`) on purpose. If you add a surface, pick its mode for what the
thing *means*.

### The palette

`themes.dark`, verbatim. Catppuccin survives only as the status hues, exactly as in the DS.

```
ground     #141414      text        #cccccc      primary    #8b2fe0  Vivid Violet
component  #171717      muted       #999999      secondary  #ff2e9a  Magenta
card       #181818      dim         #888888      tertiary   #15cdc3  Robin's Egg
shadow dk  #000000      hover       #232323
shadow lt  #555555                               status: ctp green/red/blue/peach
```

---

## 2. How it is wired

**One source of truth: `theme/tokens.json`.** `theme/gen.py` reads it and writes every generated
file. Nothing generated is hand-editable; change the tokens and re-run.

```sh
python3 theme/gen.py           # write
python3 theme/gen.py --check   # verify the tree matches the tokens (pre-flight / CI)
python3 theme/gen.py --list    # what it owns
```

The generator ports three things from the design system rather than approximating them:

| Ported | From | Why it matters |
|---|---|---|
| OKLCh shade ramps | `src/shade.ts` | sRGB washes a hue toward grey as it lightens; OKLCh keeps it vivid. The computed `light` step reproduces the DS's hand-picked `--ctp-light-primary: #9b58e7` exactly. |
| `onAccent()` contrast | `src/themes.ts` | Picks ink per brand face. Reproduces the DS's own escalation: `#8b2fe0` gets pure white, because the themed `#cdd6f4` only reaches 4.06:1. |
| Shadow *reach* (`--neu-shadow-*-gap`) | `src/theme/variables.css` | Layout gaps are sized so neighbours' shadows meet instead of piling up. It is why Hyprland's `gaps_out` is 15. |

**Nerd-font glyphs are generated too** (`quickshell/Icons.qml`), from hex codepoints in
`tokens.json`. Literal private-use characters get silently dropped between an editor and the
disk — it had already happened in this repo once, leaving `[custom.timew] symbol = ""` empty in
`starship.toml`. Every codepoint is verified present in UbuntuMono Nerd Font before use.

---

## 3. What changed

### Generated (do not edit; edit `theme/tokens.json`)

`quickshell/Theme.qml` · `quickshell/Icons.qml` · `hypr/neu.lua` · `hypr/hyprlock.conf` ·
`waybar/neu.css` · `wofi/style.css` · `dunst/dunstrc` · `ghostty/themes/neu` · `kitty/neu.conf` ·
`alacritty/neu.toml` · `tmux_conf/neu.conf` · `starship/starship.toml` · `gtk/gtk.css` ·
`gtk4/gtk.css` · `qt6ct/qt6ct.conf` · `qt6ct/neu.conf` · `theme/neu.css` · `theme/wall/*`

### The shell (new)

Quickshell grew from two slide-out panels into the whole shell. **waybar, wofi and dunst are no
longer running** — they stay installed and restyled, and panic mode brings them back.

| Surface | File | Bound to |
|---|---|---|
| Bar | `ui/bar/` | always on, top |
| Dock | `ui/dock/Dock.qml` | pointer to the bottom edge, or `ipc call dock toggle` |
| Spotlight | `ui/launcher/Spotlight.qml` | `SUPER+SPACE` (was `wofi --show drun`) |
| Notifications | `ui/notify/` | the D-Bus daemon (was dunst) |
| Control Center | `ui/control/` | the bar's right-hand chevron |
| Design probe | `ui/dev/Playground.qml` | `ipc call probe toggle` |

Primitives live in `ui/neu/` — `NeuSurface` is the whole grammar in one component
(`mode: raised | inset | flat`, `tier: xxs…xl`, and `reach`). `Neu.qml` carries the runtime
colour maths; `DockConfig.qml` is the hand-edited dock contents.

### Modified

`hypr/hyprland.lua` (look-and-feel, autostart, layer rules, `SUPER+SHIFT+ESCAPE`) ·
`hypr/hyprpaper.conf` · `ghostty/config` · `kitty/kitty.conf` (one `include` at the bottom) ·
`alacritty/alacritty.toml` · `tmux_conf/.tmux.conf` (one `source-file` after tpm) ·
`zshrc/.zshrc` (motd colours; removed the dead `pomo()`) · `install.sh` · `uninstall_config.sh` ·
`quickshell/{shell,Theme}.qml` and `ui/components/{Chip,ListRow}.qml`

### Adopted from outside the repo

These were real files; `install.sh` moved each to `<file>.predotfiles` **once** and symlinked the
repo copy. `uninstall_config.sh` puts them back.

- `~/.config/gtk-3.0/settings.ini` → `gtk/settings.ini`
- `~/.config/qt6ct/qt6ct.conf` → `qt6ct/qt6ct.conf`

New links with no prior file: `~/.config/gtk-3.0/gtk.css`, `~/.config/gtk-4.0/gtk.css`,
`~/.config/qt6ct/colors/neu.conf`, `~/.tmux-neu.conf`, `~/.config/{kitty,alacritty}/neu.*`,
`~/.config/ghostty/themes/neu`, `~/.config/hypr/neu.lua`, and `bin/neu-*.sh` / `bin/neu_*.sh`
in `~/.local/bin`.

### Housekeeping done along the way

- `~/.config/waybar/pomodoro.sh` was a dangling symlink to a file deleted in `74452af`, and
  `pomo()` in `.zshrc` called it. Both removed.
- `install.sh` still linked `.newsboat/*`, deleted in the same commit; the loop is gone.
- `starship.toml`'s timew segment had an empty symbol — a glyph lost in an earlier edit.
  Restored by codepoint.
- The waybar config declared `battery#bat0` **and** `battery#bat1`, but this machine only has
  `BAT1` in sysfs, so one module has been dead. The bar now shows whatever exists.

---

## 4. Things that are not what you would expect

**Three Quickshell services are unusable on this machine**, so the bar polls
`bin/neu_sysinfo.sh` instead of binding to them. This is not a style choice:

| Service | What happens here |
|---|---|
| `Quickshell.Services.Pipewire` | This box runs **PulseAudio**; `defaultAudioSink` is null. Volume goes through `pactl`. |
| `Quickshell.Networking` | Logs *"Could not find an available backend"* — this box runs **iwd + systemd-networkd**, not NetworkManager. Network state comes from `iw` / `ip`. |
| `Quickshell.Services.UPower` | Reports **zero devices** despite `upowerd` being active. Battery comes from `/sys/class/power_supply`. |
| `DesktopEntries` | Reports **zero applications** despite a correct `XDG_DATA_DIRS` and 94 `.desktop` files. Spotlight parses them with `bin/neu_apps.sh`. |

**Layer blur does not work.** The NeuOS menu bar is translucent over a backdrop blur.
`hyprland.lua` sets `hl.layer_rule{ blur = true }` for the `neu:*` and `quickshell:*` namespaces,
using the spelling from `/usr/share/hypr/hyprland.lua` — and Hyprland 0.56.2 ignores it. Verified
twice: `dim_around = true` on the bar never dims the screen, and dropping a panel to 45% alpha
leaves the text behind it perfectly sharp. **The shell's surfaces are therefore near-opaque**,
which is the same conclusion the pre-existing `Theme.qml` comment had already reached for the
same reason. The rules are left in place, commented, in case a later Hyprland honours them.

**Fonts.** The DS asks for `'Roboto', sans-serif`; it is not installed. The shell uses
**UbuntuMono Nerd Font** because it carries the glyphs. `pacman -S ttf-roboto` then swap
`type.font.ui` in `tokens.json` to match the DS exactly.

**The dock reveals on real pointer movement.** `hyprctl dispatch movecursor` does not generate
the pointer-enter event a layer surface needs, so it cannot be tested that way — use
`qs -c commandcenter ipc call dock toggle`, or just move the mouse to the bottom edge.

---

## 5. Getting out

Three exits, escalating. **Level 1 needs no files touched and works instantly.**

### Before you start (do this once)

```sh
~/dev/dotfiles/bin/neu-revert.sh --snapshot   # records gsettings + pre-existing files
```

Already run — the snapshot is in `~/.cache/neu-theme/`.

### Pre-flight, before rebooting into it

```sh
./install.sh --full              # reports any missing packages
python3 theme/gen.py --check     # generated tree matches the tokens
Hyprland --verify-config         # evaluates the Lua BEFORE you boot into it
qs -c commandcenter              # run in a terminal; QML errors print to stdout
```

On a fresh machine add `--packages` to install what is missing. The list is in
`install.sh`; the ones that are not obvious are `qt6-5compat` (NeuSurface's inset
shadows), `qt6-declarative` (`RectangularShadow`, the raised pair) and
`ttf-ubuntu-mono-nerd` — without that font every icon in the bar, dock, Spotlight
and prompt renders as a blank box.

`install.sh --full` also regenerates the theme when the tree does not match this
machine: `qt6ct/qt6ct.conf` embeds an absolute `$HOME`, and `hyprpaper.conf` /
`hyprlock.conf` embed the repo path, so a checkout somewhere else ships stale
paths until it runs.

### Testing the installer without touching your session

`uninstall_config.sh` removes `~/.config/hypr/hyprland.lua`, and Hyprland notices
immediately — it will put an error on screen until the link is back and you
`hyprctl reload`. So exercise the install/uninstall pair against a throwaway home
instead; both scripts are `$HOME`-clean:

```sh
rm -rf /tmp/sandhome && mkdir -p /tmp/sandhome
HOME=/tmp/sandhome ./install.sh --full --no-bootstrap --no-generate
find /tmp/sandhome -xtype l          # expect no output
HOME=/tmp/sandhome ./uninstall_config.sh -y
find /tmp/sandhome -type l           # expect no output
```

`--no-generate` matters: without it the installer regenerates the theme for the
sandbox `$HOME` and bakes `/tmp/sandhome` into `qt6ct/qt6ct.conf`. If you forget,
`python3 theme/gen.py` puts it right.

### Level 1 — panic (instant, no files touched)

**`SUPER+SHIFT+ESCAPE`**, or `neu-panic.sh`.

Kills the neu shell, starts waybar + dunst, and rebinds `SUPER+SPACE` back to wofi for the rest
of the session. Nothing on disk changes, so nothing needs undoing: `neu-shell.sh` brings the neu
shell back, or just log out and in.

There is also a watchdog: `hyprland.lua` autostarts the shell through `bin/neu-shell.sh`, which
waits for the bar's layer surface to actually appear and **falls back to waybar on its own** if
it doesn't. A QML error costs you a worse-looking bar, not a dead session.

### Level 2 — soft revert (keeps the work)

```sh
cd ~/dev/dotfiles
bin/neu-revert.sh --soft
```

Stashes the theme work, restores every `.predotfiles`, puts gsettings back, and re-runs
`install.sh`. Recover it with `git stash pop`.

### Level 3 — full uninstall (discards the work)

```sh
cd ~/dev/dotfiles
bin/neu-revert.sh          # add -y to skip the prompt
systemctl reboot
```

`uninstall_config.sh -y` → restore gsettings → `git checkout -- . && git clean -fd` →
`install.sh --full`. The script re-execs itself from `/tmp` first, because `git clean -fd` would
otherwise delete it while bash is still reading it.

Then confirm nothing dangles:

```sh
find ~/.config ~/.local/bin -maxdepth 3 -xtype l    # expect no output
git -C ~/dev/dotfiles status --short                # expect empty
```

### What a revert cannot leave behind

- **No packages.** Nothing was installed with `pacman`. Every tool used (`grim`, `rsvg-convert`,
  `pactl`, `iw`, `jq`, `python3`) was already here.
- **No dconf writes** except the `gsettings` keys recorded in the snapshot, restored on revert.
- **Nothing outside** `~/.config`, `~/.local/bin`, `~/.tmux.conf`, `~/.tmux-neu.conf`, `~/.zshrc`.
- **`~/Pictures` untouched.** The wallpaper is generated into `theme/wall/`; `purp_green.jpg`
  is exactly where it was, and reverting `hypr/hyprpaper.conf` points back at it.

### If the reboot goes wrong

1. The `neu-shell.sh` watchdog should already have given you waybar.
2. If Hyprland itself won't parse the config it falls back to its **built-in defaults**, where
   `SUPER+Q` opens a terminal. From there: `~/dev/dotfiles/bin/neu-revert.sh -y`.
3. Floor: `Ctrl+Alt+F2` for a TTY, log in, same command. It does not need a graphical session.

---

## 6. Not done

- **Neovim** is its own git repo at `~/.config/nvim` and was left alone. To match, add to
  `lua/jwbla/plugins/catppuccin.lua` an `opts.color_overrides.mocha` block mapping `base`
  → `#141414`, `mantle` → `#0f0f0f`, `crust` → `#000000`, `text` → `#cccccc`,
  `mauve` → `#8b2fe0`, `pink` → `#ff2e9a`, `teal` → `#15cdc3`.
- **cava, bat, television** have configs outside this repo and are unthemed.
- The bar has no per-module popovers yet (click the clock to toggle the date; that is all).
