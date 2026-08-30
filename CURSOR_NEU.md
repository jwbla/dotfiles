# The neu cursor

A cursor theme drawn from the same `theme/tokens.json` as the rest of the desktop:
`--neu-text` fill, `--neu-accent-text` edge, `--neu-shadow-dark` cast.

**It is already built, linked and applied.** Nothing here needs `sudo`. This file
exists so you can see what was done, change it, and back it out — §4 is the
revert.

---

## 1. What you have

11 drawn shapes, 88 cursor names, six sizes (24/32/36/48/64/96), in two formats:

| Theme | Path | Serves |
|---|---|---|
| Xcursor | `~/.icons/neu` → `theme/cursor/build/xcursor/neu` | XWayland, GTK, Qt, everything X11 |
| hyprcursor | `~/.local/share/icons/neu` → `theme/cursor/build/hypr/neu` | Hyprland's own native cursor path |

Both are called `neu` but live in **different roots on purpose**: they each need a
`cursors/` directory, and Xcursor would choke trying to parse hyprcursor's `.hlc`
files. `~/.icons` is searched first, so the right one always wins.

Shapes: arrow, I-beam, pointing hand, crosshair, move, four resize arrows,
not-allowed, and an animated busy ring (12 frames at the DS's 0.8s spinner
period). The other 77 names — `default`, `pointer`, `ew-resize`, `nwse-resize`,
the MD5-looking legacy names X11 apps still ask for — are aliases onto those.
A missing alias is how a theme ends up looking half-applied, so the full soup is
covered.

## 2. How it's built

```sh
python3 theme/cursor/gen_cursor.py            # rebuild
python3 theme/cursor/gen_cursor.py --sheet    # + a contact sheet in /tmp
```

- `theme/cursor/shapes.py` — the artwork, as fill-only SVG paths on a 24×24 grid,
  plus the alias map. Fill-only matters: the outline is made by drawing each shape
  twice, once dilated by a stroke in the accent colour, and a path carrying its
  own `stroke-width` would escape that dilation.
- `theme/cursor/xcursor.py` — the Xcursor container, written directly. **This is
  why nothing needs installing**: no `xcursorgen`, no `clickgen`, no AUR. It is
  verified by round-tripping every real cursor in `/usr/share/icons/Adwaita`
  byte-for-byte:
  ```sh
  python3 theme/cursor/xcursor.py     # "round-trip: 35 identical, 0 mismatched"
  ```
- `theme/cursor/gen_cursor.py` — renders each shape at each size with
  `rsvg-convert`, encodes the Xcursor files, and drives `hyprcursor-util` for the
  native theme.

Only `rsvg-convert`, `ffmpeg` and `hyprcursor-util` are used, all already present.

## 3. Operator steps

### Already done

`install.sh` links both themes, `hypr/hyprland.lua` exports `XCURSOR_THEME=neu`
and `HYPRCURSOR_THEME=neu`, `gtk/settings.ini` sets `gtk-cursor-theme-name=neu`,
and these were applied live:

```sh
hyprctl setcursor neu 36
gsettings set org.gnome.desktop.interface cursor-theme neu
```

### What you still need to do

**Relaunch apps to see it everywhere.** A client reads its cursor theme from the
environment at startup, so anything running from before the change keeps the old
one — a terminal will still show Adwaita's I-beam until you open a new window.
A fresh Hyprland session picks it up everywhere at once.

### Optional: system-wide (this is the only part that wants sudo)

Only needed if the display manager's greeter or another user should get it too.
Copies rather than links, because `/usr/share` should not point into your home:

```sh
sudo cp -rL ~/dev/dotfiles/theme/cursor/build/xcursor/neu /usr/share/icons/neu
sudo cp -rL ~/dev/dotfiles/theme/cursor/build/hypr/neu    /usr/share/icons/neu-hypr
```

Note it will not track rebuilds — re-run the copy after `gen_cursor.py`. To undo:
`sudo rm -rf /usr/share/icons/neu /usr/share/icons/neu-hypr`.

### Optional: size

36px, from `XCURSOR_SIZE` / `HYPRCURSOR_SIZE` in `hypr/hyprland.lua`. Change both,
then `hyprctl setcursor neu <size>`.

## 4. Changing it

- **Colours** follow the tokens automatically — edit `theme/tokens.json`, run
  `python3 theme/cursor/gen_cursor.py`, then `hyprctl setcursor neu 36`.
- **Shapes** live in `theme/cursor/shapes.py`. Each entry is
  `(hotspot_x, hotspot_y, svg_body, frames)` in the 24-unit grid; hotspots scale
  with the rendered size. Add a name to `ALIASES` to point another X11 cursor name
  at an existing shape.
- **A new shape** needs an entry in `SHAPES` and, usually, aliases. Check it with
  `--sheet` before installing — at 24px a shape that reads fine at 96px often does
  not.

## 5. Backing it out

Covered by the main revert in `NEU_THEME.md` §5 — `uninstall_config.sh` drops both
symlinks, and `bin/neu-revert.sh --snapshot` recorded your original
`cursor-theme` gsetting, which the full revert restores.

Cursor only, without touching anything else:

```sh
rm -f ~/.icons/neu ~/.local/share/icons/neu
gsettings set org.gnome.desktop.interface cursor-theme Adwaita
hyprctl setcursor Adwaita 36
```

Then drop the two `hl.env` lines from `hypr/hyprland.lua` and
`gtk-cursor-theme-name` from `gtk/settings.ini`, or just `git checkout` them.
Nothing was installed with `pacman`, and nothing outside `~/.icons`,
`~/.local/share/icons` and the one gsettings key was touched.
