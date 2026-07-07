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
  television (`tv`)
- **desktop**: hyprland, waybar, wofi, dunst, newsboat, taskwarrior (motd),
  ghostty/kitty/alacritty
