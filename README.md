# .files

Portable dotfiles — zsh, tmux, atuin, the tms session manager, and the base
terminal configs. Installed as symlinks by `install.sh`. No stow or other
dependencies, plain `ln`.

These run everywhere: the Arch desktop, a Mac, a Coder workspace. Nothing here
needs a display server, and nothing here depends on the repo below.

> **The desktop is a separate repo.** Hyprland, the quickshell *neu* shell, the
> theme and the fleet tools live in `gitea.i.realgamers.tv/jwbla/dotfiles`, which
> installs *on top* of this one. It overrides the palettes here through optional
> includes, so a machine with only this repo is a complete, working setup and a
> machine with both reverts cleanly by uninstalling that one.

```sh
./install.sh              # auto: full on a desktop (Linux or macOS), minimal in Coder
./install.sh --packages   # ... and install any missing packages (pacman, apt or brew)
./install.sh --minimal    # portable CLI only, no terminal configs
./install.sh --help
```

Packages are never installed without `--packages`; otherwise the script just
reports what is missing. On macOS the terminals themselves (ghostty, kitty) are
casks and stay a manual install; only their configs are linked.

Both scripts run on stock macOS bash 3.2 and BSD userland: no associative
arrays, namerefs, `date -I` or GNU-only flags. Check a change with
`docker run --rm --network none -v "$PWD":/src:ro bash:3.2 bash -n /src/install.sh`.

## Install

### Desktop (Linux or macOS)

```
./install.sh
```

Links zsh, tmux, starship, atuin, dex, git aliases and the tms project
configs, plus — on any desktop — the kitty/alacritty/ghostty configs. On
Linux it also links the scripts in `bin/` into `~/.local/bin`, so nothing
depends on where this repo is cloned; they read sysfs, so a Mac gets none.

Re-running it also removes any symlink into this repo whose target no longer
exists — what an older revision linked and a later one moved or dropped.

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
  television (`tv`), atuin (Ctrl+R / Up history search — see below),
  zsh-syntax-highlighting + zsh-autosuggestions (command-line coloring and
  ghost-text completions; skipped when absent)
- **desktop**: ghostty/kitty/alacritty

## Terminals and the neu palette

The three terminal configs here are Catppuccin Mocha and complete on their
own. Each ends in an *optional* include that the rgtv repo satisfies when it
is installed and that is silently skipped otherwise:

| config | include | absent |
|---|---|---|
| `ghostty/config` | `config-file = ?neu.conf` | `?` skips it (ghostty ≥ 1.1) |
| `kitty/kitty.conf` | `globinclude neu.conf` | matches zero files |
| `alacritty/alacritty.toml` | `import = [...neu.toml]` | alacritty skips missing imports |

Nothing in this repo may name a file only the rgtv repo ships. If a machine
with only this repo shows ghostty complaining about a theme called `neu`, its
checkout predates the split that moved the theme out (`4d67dbb`):

```
git pull && ./install.sh
```

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

## dex

`dex/config.toml` is symlinked to `~/.config/dex/config.toml` and points the
`dex` CLI (the fleet's agile-PM tool) at the shared server
(`http://192.168.1.204:3000`) instead of a machine-local SQLite file, the
same way every other client (web UI, MCP) already reaches it. See dex's own
README for what "remote mode" does and how the CLI decides local vs. remote.

The bearer token is deliberately **not** in this repo — `config.toml` only
names a `token_file`, `~/.config/dex/token`, and install.sh prints a one-line
reminder if that file is missing or empty:

```
echo '<your dex bearer token>' > ~/.config/dex/token && chmod 600 ~/.config/dex/token
```

Mint a token on the server with `dex apikey create <name>` (or ask whoever
already has one). `chmod 600` matters: unlike `config.toml`, this file holds
a live credential.
