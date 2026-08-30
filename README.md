# .files

Personal dotfiles, installed as symlinks by `install.sh`. No stow or other
dependencies — plain `ln`.

```sh
./install.sh              # auto: full on a Linux desktop, minimal on macOS / Coder
./install.sh --packages   # ... and install any missing packages (pacman or brew)
./install.sh --minimal    # portable CLI only, no desktop configs
./install.sh --help
```

`--full` is Linux-only and is refused elsewhere, so running this on the Mac will
not scatter `~/.config/hypr` and friends into a home that cannot use them.
Packages are never installed without `--packages`; otherwise the script just
reports what is missing.

## Install

### Desktop (Arch/Hyprland)

```
./install.sh
```

Links everything: zsh, tmux, starship, git aliases, plus hyprland, waybar,
wofi, dunst, kitty/alacritty/ghostty, newsboat, and tms project configs.
Utility scripts in `bin/` are linked into `~/.local/bin`, so nothing depends
on where this repo is cloned.

### Coder workspaces

Point the workspace's dotfiles URL at this repo (or run
`coder dotfiles <repo-url>`). Coder clones it to `~/.config/coderv2/dotfiles`
and runs `install.sh`, which detects the workspace and:

- links only the CLI subset (zsh, tmux, starship, git aliases,
  tmux-session-manager)
- best-effort installs starship (to `~/.local/bin`) and tmux TPM if missing —
  skipped with a warning when offline

### Flags

- `--full` / `--minimal` — override the auto-detected mode
- `--no-bootstrap` — link configs only, skip tool installation

### Behavior

- Idempotent — safe to re-run (Coder re-runs it on every workspace start).
- A pre-existing real file at a target path is preserved as
  `<file>.predotfiles` before being replaced with a symlink.

## Uninstall

```
./uninstall_config.sh        # add -y to skip the prompt
```

Removes every symlink pointing into this repo and restores `.predotfiles`
backups.

## tmux

TPM is auto-installed in workspaces. On the desktop:

```
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

then `ctrl+b I` inside tmux to install plugins.

## nerdfont

pick nerdfont
unzip to ~/.fonts

```
fc-cache -fv
```

## Dependencies

The zshrc degrades gracefully when tools are missing, but expects:

- **core**: zsh, tmux, starship, fzf
- **nice to have**: eza (`l`/`lt`), bat (`inv` preview), zoxide, git-delta,
  television (`tv`), atuin (Ctrl+R / Up history search — see below)
- **desktop**: hyprland, waybar, wofi, dunst, newsboat, taskwarrior (motd),
  ghostty/kitty/alacritty
- **quickshell**: the whole desktop shell — bar, dock, Spotlight (`SUPER+SPACE`),
  notifications, Control Center, plus the Command Center panel on ``SUPER+` `` and
  the rgtv glance on `SUPER+R`. Needs taskwarrior + timewarrior.
- **theme**: the desktop wears `@rgtv/neu` (see `NEU_THEME.md`). One source of
  truth in `theme/tokens.json`; `python3 theme/gen.py` regenerates every themed
  config. **Read `NEU_THEME.md` §5 before a test drive — it is how you back out.**
  timewarrior. Without it that bind does nothing; `SUPER+A` still opens the
  wofi tmux picker.
- **rgtv glance** (`SUPER+R`, same quickshell instance): the rgtv fleet at a
  glance — firing Prometheus alerts, open Gitea PRs with their CI state,
  whether every repo's master is green, fleet services with the homepage's
  health probe, and Grafana dashboards. Everything is a clickable link;
  right-click on a PR or repo jumps to CI. Data comes from
  `bin/rgtv_glance.sh` (curl + jq against the LAN; the Gitea token is read
  from `tea`'s login, so `tea login add` once for gitea.i.realgamers.tv).
  Re-polls every 30s while open; `qs -c commandcenter ipc call rgtv refresh`
  forces one from a script.

## atuin

Shell history lives in atuin's SQLite db (`~/.local/share/atuin/history.db`)
instead of being grepped out of `~/.zsh_history`. The zshrc guard means
machines without atuin fall back to zsh's `Ctrl+R` untouched.

```
sudo pacman -S atuin      # Arch; extra/atuin
atuin import auto         # one-time: pull in existing ~/.zsh_history

# one-time: the alias store below is encrypted and `atuin init` refuses to
# run without a key. register/login would create one; with no sync server:
openssl rand 32 | base64 -w0 > ~/.local/share/atuin/key
chmod 600 ~/.local/share/atuin/key
```

Skip that key step and every new shell prints `could not load encryption key`,
`atuin init` exits 1, and no hooks install — `Ctrl+R` quietly falls back to
zsh and nothing is recorded.

`atuin/config.toml` is symlinked to `~/.config/atuin/config.toml`. It ships a
`history_filter` that drops noise (single-char aliases, bare `ls`/`cd`) and
anything carrying `--password`/`--token`.

**Cleaning history** — filters only apply going forward, so after editing
`history_filter`:

```
atuin history prune --dry-run     # preview what the filters would remove
atuin history prune               # commit
atuin search --delete '<query>'   # delete by query (refuses to run bare)
atuin history dedup --before <date> --dupkeep 1
```

In the search TUI, `Ctrl+O` opens the inspector on the highlighted entry and
`Ctrl+D` deletes it.

**Preserving commands** — atuin has no pin/favorite flag; history is meant to
be disposable. Commands worth keeping permanently go in this repo
(`zshrc/.zshrc`), or in atuin's own alias store, which no prune or delete
touches:

```
atuin dotfiles alias set deploy 'some long command'
atuin dotfiles alias list
```

Sync is off (`auto_sync = false`) — there's no server yet. The key at
`~/.local/share/atuin/key` was generated locally (see above) rather than by
`atuin register`. Back it up before adding a server: sync is end-to-end
encrypted and the server cannot recover that key for you.
