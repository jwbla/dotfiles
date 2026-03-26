# User Manual - Keybindings & Configuration

Theme: Catppuccin Mocha (across Hyprland, tmux, neovim, and dunst)

---

## Hyprland

Modifier: `Super` (Windows key)

### App Launchers

| Key | Action |
|-----|--------|
| `Super+Space` | App launcher (wofi) |
| `Super+Q` | Terminal (ghostty) |
| `Super+F` | Browser (librewolf) |
| `Super+W` | Chromium |
| `Super+E` | File manager (dolphin) |
| `Super+D` | Database manager (sqlitebrowser) |
| `Super+G` | FreeTube |
| `Super+V` | Clipboard history (copyq) |

### Window Navigation

| Key | Action |
|-----|--------|
| `Super+H` | Focus left |
| `Super+J` | Focus down |
| `Super+K` | Focus up |
| `Super+L` | Focus right |

### Window Swapping

| Key | Action |
|-----|--------|
| `Super+Shift+H` | Swap window left |
| `Super+Shift+J` | Swap window down |
| `Super+Shift+K` | Swap window up |
| `Super+Shift+L` | Swap window right |

### Window Management

| Key | Action |
|-----|--------|
| `Super+C` | Close active window |
| `Super+M` | Toggle fullscreen (monocle, keeps gaps) |
| `Super+T` | Toggle split (dwindle) |
| `Super+LMB` (drag) | Move window |
| `Super+RMB` (drag) | Resize window |

### Workspaces

| Key | Action |
|-----|--------|
| `Super+1`-`0` | Switch to workspace 1-10 |
| `Super+Shift+1`-`0` | Move window to workspace 1-10 |
| `Super+Tab` | Workspace/window switcher (wofi) |
| `Super+Scroll` | Cycle workspaces |
| `Super+S` | Toggle scratchpad |
| `Super+Shift+S` | Move window to scratchpad |

### System

| Key | Action |
|-----|--------|
| `Super+Z` | Lock screen (hyprlock) |
| `Volume Up/Down/Mute` | pactl volume control |
| `Brightness Up/Down` | Custom brightness script (steps of 250) |

### Settings

- Layout: dwindle (pseudotile enabled, preserve split)
- Gaps: 1px in/out, border 2px
- Active border: animated pink/purple gradient
- Window opacity: 95% active, 90% inactive with blur
- Rounded corners: 5px
- Animations enabled (custom bezier curves, looping border angle)
- Natural scroll on touchpad
- Razer Naga: flat accel profile, -0.5 sensitivity
- Workspace 10 bound to HDMI-A-1 when connected
- Autostart: hyprpaper, waybar, ghostty

---

## Tmux

Leader: `Ctrl+B` (default)

### Window Selection

| Key | Action |
|-----|--------|
| `F1`-`F10` | Jump to window 1-10 |
| `Ctrl+Alt+N` | New window |
| `Ctrl+Alt+,` | Rename current window |

### Session Management

| Key | Action |
|-----|--------|
| `Ctrl+Alt+C` | Create new session (prompts for name) |
| `Ctrl+Alt+Z` | Previous session |
| `Ctrl+Alt+X` | Next session |
| `Ctrl+Alt+T` | Session tree picker |
| `Ctrl+Alt+D` | Detach from session |

### Pane Navigation

| Key | Action |
|-----|--------|
| `Ctrl+Alt+H` | Move to left pane |
| `Ctrl+Alt+J` | Move to pane below |
| `Ctrl+Alt+K` | Move to pane above |
| `Ctrl+Alt+L` | Move to right pane |

### Pane Swapping

| Key | Action |
|-----|--------|
| `Ctrl+Alt+Shift+H` | Swap pane left |
| `Ctrl+Alt+Shift+J` | Swap pane down |
| `Ctrl+Alt+Shift+K` | Swap pane up |
| `Ctrl+Alt+Shift+L` | Swap pane right |

### Splits

| Key | Action |
|-----|--------|
| `Ctrl+Alt+V` | Vertical split |
| `Ctrl+Alt+S` | Horizontal split |
| `prefix` + `v` | Vertical split (prefix mode) |
| `prefix` + `s` | Horizontal split (prefix mode) |

### Other

| Key | Action |
|-----|--------|
| `Ctrl+Alt+Q` | Kill pane |

### Plugins

- **tpm** - plugin manager
- **tmux-sensible** - sensible defaults
- **tmux-resurrect** - persist sessions across restarts (nvim session strategy enabled)
- **tmux-continuum** - auto-save/restore sessions

### Settings

- Windows and panes start at index 1
- Auto-renumber windows on close
- System clipboard enabled
- Status bar: top, shows hostname and session name

---

## Neovim

Leader: `Space`

### File Navigation (Telescope)

| Key | Action |
|-----|--------|
| `Space Space` | Find files |
| `Space pf` | Find files |
| `Ctrl+P` | Git files |
| `Space ps` | Grep string (prompted) |
| `Space pg` | Live grep |
| `Space pb` | Open buffers |
| `Space vh` | Help tags |
| `Space pt` | Search tree (floating) |

### File Explorer

| Key | Action |
|-----|--------|
| `Space pv` | Open netrw (`:Ex`) |

### Window/Split Navigation

| Key | Action |
|-----|--------|
| `Ctrl+H` | Move to left window |
| `Ctrl+J` | Move to window below |
| `Ctrl+K` | Move to window above |
| `Ctrl+L` | Move to right window |

### Window/Split Swapping

| Key | Action |
|-----|--------|
| `Ctrl+Shift+H` | Swap window left |
| `Ctrl+Shift+J` | Swap window down |
| `Ctrl+Shift+K` | Swap window up |
| `Ctrl+Shift+L` | Swap window right |

### Window/Split Resizing

| Key | Action |
|-----|--------|
| `Alt+,` | Shrink width (5 cols) |
| `Alt+.` | Grow width (5 cols) |
| `Alt+T` | Grow height |
| `Alt+S` | Shrink height |

### Creating Splits

| Key | Action |
|-----|--------|
| `Ctrl+\` | Vertical split |
| `Ctrl+Shift+\` | Horizontal split |

### LSP

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `K` | Hover info |
| `Space vws` | Workspace symbol search |
| `Space vd` | Open diagnostic float |
| `Space ca` | Code action |
| `Space vrr` | References |
| `Space vrn` | Rename symbol |
| `Ctrl+H` (insert) | Signature help |
| `[d` | Next diagnostic |
| `]d` | Previous diagnostic |

### Autocompletion (nvim-cmp)

| Key | Action |
|-----|--------|
| `Ctrl+P` | Select previous item |
| `Ctrl+N` | Select next item |
| `Ctrl+Y` | Confirm selection |
| `Ctrl+Space` | Trigger completion |
| `Tab` | Jump to next snippet placeholder |
| `Shift+Tab` | Jump to previous snippet placeholder |

### Trouble (Diagnostics)

| Key | Action |
|-----|--------|
| `Space tt` | Toggle diagnostics |
| `Space tT` | Toggle buffer diagnostics |
| `Space cs` | Toggle symbols |
| `Space cl` | Toggle LSP definitions/references |
| `Space xL` | Toggle location list |
| `Space xQ` | Toggle quickfix list |

### Git

| Key | Action |
|-----|--------|
| `Space gb` | Git blame (fugitive) |

### Editing

| Key | Action |
|-----|--------|
| `Space fr` | Find and replace word under cursor |
| `Ctrl+/` | Toggle comment (normal & visual) |
| `Alt+J` (visual) | Move selected lines down |
| `Alt+K` (visual) | Move selected lines up |
| `Ctrl+Backspace` (insert) | Delete word backward |

### Terminal

| Key | Action |
|-----|--------|
| `Ctrl+N` | Toggle bottom terminal split |
| `Space r` (visual) | Run selection in floating terminal (FTerm) |
| `Space js` | Run current .js file in node, or open node REPL |

### Utilities

| Key | Action |
|-----|--------|
| `Space u` | Toggle undo tree |
| `Space zm` | Toggle zen mode |
| `Space /` | Toggle comment visibility (hide/show) |
| `Space fu` | Make it rain (cellular automaton) |
| `:WordWrap` | Toggle word wrap |

### Surround (vim-surround)

| Key | Action |
|-----|--------|
| `cs"'` | Change surrounding `"` to `'` |
| `ds"` | Delete surrounding `"` |
| `ysiw)` | Surround word with `()` |
| `S"` (visual) | Surround selection with `"` |

### Editor Settings

- Relative line numbers
- 4-space tabs, expandtab, smart indent
- No word wrap
- No swapfile or backup, persistent undo
- Incremental search, no highlight after search
- Scroll offset: 8 lines
- Color column at 100
- Fold method: indent (folds open by default)
- `.gltf` files treated as JSON

### LSP Servers (via Mason)

lua_ls, clangd, jsonls, html, glsl_analyzer, ts_ls, gopls, yamlls, bashls, sqlls, cmake, zls

---

## Shell (zsh)

### Key Bindings

| Key | Action |
|-----|--------|
| `Ctrl+R` | Reverse history search |

Vi mode enabled (`bindkey -v`).

### Aliases

| Alias | Expands To |
|-------|------------|
| **Editor** | |
| `n` | `nvim .` |
| `nv` | `nvim` |
| `inv` | Open fzf file picker with bat preview, open in nvim |
| **Tmux** | |
| `t` | Smart tmux session picker (fzf, create or attach) |
| `tm` | `tmux` |
| `ta` | `tmux a` (attach) |
| `tat` | `tmux a -t` (attach to named) |
| `tns` | `tmux new -s` (new named session) |
| `tls` | `tmux list-sessions` |
| `tks` | `tmux kill-server` |
| **Git** | |
| `gbf` | Fuzzy branch switcher (fzf + git checkout) |
| **File Listing (eza)** | |
| `l` | Long list, icons, git status, all files |
| `lt` | Tree (2 levels), long, icons, git |
| `ltree` | Tree (2 levels), icons, git |
| **Misc** | |
| `nb` | `newsboat -r` |
| `oc` | `opencode` |

### Functions

- **`load_tmux` (aliased to `t`)** - Smart session manager: if inside tmux, fzf picker to switch or create sessions. If outside, attach to existing or start new. Always offers a "+ New Session" option.
- **`pomo`** - Pomodoro timer, triggers waybar update via signal.
- **`_motd`** - Shell greeting on startup: shows date, active tmux sessions, taskwarrior items due within 24h, and overdue count.

### Tools & Prompt

- **Starship** - custom prompt
- **Zoxide** - smart `cd` (`z` command)
- **tv** - terminal viewer
- **fzf** - fuzzy finder (used in aliases and functions)
- **eza** - modern `ls` replacement
- **bat** - cat with syntax highlighting (used in fzf preview)
- **Oh-My-Zsh** - framework (git plugin)
- **Taskwarrior** - task management (surfaced in MOTD)

### Environment

- `$BROWSER` = librewolf
- `$PATH` includes `~/.local/bin`, `~/.cargo/bin`, `~/.opencode/bin`

---

## Design Patterns

There is a consistent navigation philosophy across all layers:

| Layer | Navigate | Swap | Modifier |
|-------|----------|------|----------|
| **Hyprland windows** | `Super+HJKL` | `Super+Shift+HJKL` | `Super` |
| **Tmux panes** | `Ctrl+Alt+HJKL` | `Ctrl+Alt+Shift+HJKL` | `Ctrl+Alt` |
| **Nvim windows** | `Ctrl+HJKL` | `Ctrl+Shift+HJKL` | `Ctrl` |

The modifier escalates by scope: `Ctrl` (nvim) < `Ctrl+Alt` (tmux) < `Super` (compositor). Adding `Shift` always means "swap" instead of "move". HJKL is used for directional movement at every level.

Workspaces and windows use number keys at their respective layers:
- Hyprland workspaces: `Super+1`-`0`
- Tmux windows: `F1`-`F10`

Fuzzy finding is a recurring pattern:
- `Space Space` / `Space pf` in nvim (telescope)
- `t` in shell (fzf tmux picker)
- `inv` in shell (fzf file picker into nvim)
- `gbf` in shell (fzf branch picker)
- `Super+Tab` in Hyprland (wofi window picker)
- `Super+Space` in Hyprland (wofi app launcher)

