# .files

Personal dotfiles, installed as symlinks by `install.sh`. No stow or other
dependencies — plain `ln`.

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

## atuin

Shell history lives in atuin's SQLite db (`~/.local/share/atuin/history.db`)
instead of being grepped out of `~/.zsh_history`. The zshrc guard means
machines without atuin fall back to zsh's `Ctrl+R` untouched.

```
sudo pacman -S atuin      # Arch; extra/atuin
atuin import auto         # one-time: pull in existing ~/.zsh_history
```

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

Sync is off (`auto_sync = false`) — there's no server yet. If one is added,
back up `~/.local/share/atuin/key` first; sync is end-to-end encrypted and the
server cannot recover that key for you.
