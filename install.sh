#!/usr/bin/env bash
# Portable dotfiles: zsh, tmux, atuin, the tms session manager, and the base
# terminal configs. Runs on every machine the operator touches -- the Arch
# desktop, a Mac, a Coder workspace -- and must be idempotent and prompt-free on
# all of them, because workspaces run it non-interactively on every start.
#
#   minimal   the portable CLI. Coder workspaces get this.
#   full      minimal + the GUI terminal configs. The Arch desktop and the Mac
#             get this; the laptop scripts in bin/ are Linux-only within it.
#
# THE DESKTOP IS A SEPARATE REPO. Hyprland, the quickshell "neu" shell, the
# theme and the fleet tools live in gitea.i.realgamers.tv/jwbla/dotfiles, which
# installs ON TOP of this one and overrides the palettes here. Nothing in this
# repo depends on that one: every seam it uses is an optional include, so a
# machine with only this repo is a complete, working setup.
#
# Package installation is OPT-IN (`--packages`). Without it the script only
# reports what is missing, so a workspace start never blocks on a package
# manager and nothing is installed behind your back.
#
# BASH 3.2. Stock macOS ships the last GPLv2 bash and nothing newer, and this
# has to run there before brew exists. So: no associative arrays, no namerefs,
# no `date -I`, no GNU-only flags. The lookups below are case statements for
# that reason, and a `declare -A` here would kill the script under set -e
# before a single link is made.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------------ stamps --
# Both dotfiles repos drop a stamp so each can see the other. State, not config:
# nothing here is worth backing up, and a stale stamp must never outlive the
# checkout it names.
STAMP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"

write_stamp() {
    mkdir -p "$STAMP_DIR"
    { echo "repo=$SCRIPT_DIR"
      echo "commit=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
      echo "mode=$MODE"
      echo "installed=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$STAMP_DIR/$1.stamp"
}

MODE=""
BOOTSTRAP=1
PACKAGES=0
for arg in "$@"; do
    case "$arg" in
        --minimal) MODE=minimal ;;
        --full) MODE=full ;;
        --no-bootstrap) BOOTSTRAP=0 ;;
        --packages) PACKAGES=1 ;;
        -h|--help)
            awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"
            echo
            echo "usage: $0 [--minimal|--full] [--packages] [--no-bootstrap]"
            exit 0 ;;
        *) echo "usage: $0 [--minimal|--full] [--packages] [--no-bootstrap]" >&2; exit 2 ;;
    esac
done

case "$(uname -s)" in
    Darwin) OS=macos ;;
    Linux)  OS=linux ;;
    *)      OS=other ;;
esac

# Default full unless this is positively a headless box: wrong-full in a
# workspace links a couple of terminal configs nothing reads, wrong-minimal on a
# desktop silently drops them. A Mac IS a desktop here: ghostty and kitty are
# native there and read ~/.config exactly as on Linux, and a ghostty left
# unmanaged is how the work machine kept a pre-split config that named a theme
# only the rgtv repo ships.
if [[ -z "$MODE" ]]; then
    if [[ "$OS" == "other" ]]; then
        MODE=minimal
    # CODER_AGENT_TOKEN is the one the Coder template actually exports; CODER and
    # CODER_AGENT_URL are not set in a startup_script, and the checkout is not
    # under coderv2/ when workspace-init clones it to ~/dev. Missing all of them
    # is how a workspace silently came up in full mode.
    elif [[ -n "${CODER_AGENT_TOKEN:-}" || "${CODER:-}" == "true" \
            || -n "${CODER_AGENT_URL:-}" || "$SCRIPT_DIR" == */coderv2/dotfiles* ]]; then
        MODE=minimal
    else
        MODE=full
    fi
fi

echo "📦 Installing dotfiles ($MODE mode, $OS) from $SCRIPT_DIR"

# link <repo-relative-src> <absolute-dst>
# A pre-existing real file (or directory) at dst is moved to dst.predotfiles
# once; an existing backup is never overwritten, since the first one is the
# genuine pre-dotfiles state.
link() {
    local src="$SCRIPT_DIR/$1" dst="$2"
    if [[ ! -e "$src" ]]; then
        echo "  ⚠️  missing $src, skipping"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        if [[ -e "$dst.predotfiles" ]]; then
            echo "  ⚠️  $dst exists and $dst.predotfiles already present; not touching"
            return 0
        fi
        echo "  ℹ️  backing up $dst to $dst.predotfiles"
        mv "$dst" "$dst.predotfiles"
    fi
    ln -sfn "$src" "$dst"
    echo "  ✅ $dst"
}

# A symlink into this repo whose target no longer exists can only be a leftover
# from an older revision of this repo, and it is worth removing on every run:
# the pre-split installer linked ~/.config/ghostty/themes/neu, the split moved
# that file to the rgtv repo, and a machine that pulled but never re-ran the
# installer kept the dangling link next to a config that still said
# `theme = neu`. Confined to the directories this repo links into, and to links
# that name $SCRIPT_DIR, so another repo's links are never touched.
prune_stale_links() {
    local dir l target
    for dir in "$@"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r l; do
            target="$(readlink "$l" 2>/dev/null || true)"
            if [[ "$target" == "$SCRIPT_DIR"/* && ! -e "$l" ]]; then
                rm -f "$l"
                echo "  🧹 removed stale $l -> $target"
            fi
        done < <(find "$dir" -maxdepth 1 -type l 2>/dev/null)
    done
}

# ---------------------------------------------------------------- packages --
# One canonical list (Arch names), plus per-manager overrides. Three parallel
# arrays duplicated nine identical strings at two managers and would not survive
# a third.
#
# Package name and proving binary are DIFFERENT axES, which is why PKG_BIN
# exists: neovim's binary is `nvim`, so a `command -v neovim` check never fires
# and the installer would happily apt-install a downgrade over a newer build.
PKGS_CLI=(zsh tmux starship atuin jq fzf eza zoxide neovim git)

# Terminals, installed on a Linux desktop only: on macOS both are casks that
# `brew install` may or may not resolve, so they stay a manual step there. The
# configs are linked on every desktop regardless; these are just what reads them.
PKGS_TERM=(ghostty kitty)

# pkg_for <mgr> <canonical> -> the name there. Unlisted means "spelled the
# same". "-" means NOT PACKAGED HERE, and pkg_boot is how it actually arrives.
pkg_for() {
    case "$1:$2" in
        apt:starship) printf '%s' - ;;   # not in the Ubuntu archive at all
        apt:atuin)    printf '%s' - ;;   # ditto
        apt:neovim)   printf '%s' - ;;   # 24.04 ships 0.9.5; treat as unpackaged
                                         # rather than downgrade a newer build
        brew:timew)   printf '%s' timewarrior ;;
        *)            printf '%s' "$2" ;;
    esac
}

# pkg_bin <canonical> -> what proves the need is already met, when that is not
# the package name.
pkg_bin() {
    case "$1" in
        neovim) printf '%s' nvim ;;
        *)      printf '%s' "$1" ;;
    esac
}

# pkg_boot <canonical> -> how a "-" package arrives instead, or nothing. These
# land in $HOME, which is the half that survives a container being recreated,
# so they are worth running unconditionally.
pkg_boot() {
    case "$1" in
        starship) printf '%s' bootstrap_starship ;;
        atuin)    printf '%s' bootstrap_atuin ;;
        *)        printf '%s' "" ;;
    esac
}

# Prompt-freeness has to be structural: this script runs unattended on every
# workspace start, and a sudo password prompt there hangs the boot forever.
setup_sudo() {
    SUDO=""
    (( EUID == 0 )) && return 0
    if sudo -n true 2>/dev/null; then
        SUDO="sudo -n"
    elif [[ -t 0 ]]; then
        SUDO="sudo"
    else
        echo "📦 No passwordless sudo and no terminal; reporting only."
        PACKAGES=0
    fi
}

pkg_installed() {  # <mgr> <name>
    case "$1" in
        pacman) pacman -Qq "$2" &>/dev/null ;;
        apt)    [[ "$(dpkg-query -W -f='${db:Status-Status}' "$2" 2>/dev/null)" == installed ]] ;;
        brew)   brew list --versions "$2" &>/dev/null ;;
    esac
}

# triage <canonical>... splits the list three ways: MISS (installable by
# $PKG_MGR), BOOT (unpackaged here but with a handler), UNAVAIL (unpackaged, no
# handler -- say so and move on). Takes the names as arguments, not a nameref.
MISS=() BOOT=() UNAVAIL=()
triage() {
    local c name
    for c in "$@"; do
        # A binary already on PATH means the need is met however it got there --
        # starship and atuin arrive via bootstrap, zoxide/eza are often cargo.
        command -v "$(pkg_bin "$c")" >/dev/null 2>&1 && continue
        name="$(pkg_for "$PKG_MGR" "$c")"
        if [[ "$name" == "-" ]]; then
            if [[ -n "$(pkg_boot "$c")" ]]; then BOOT+=("$c"); else UNAVAIL+=("$c"); fi
            continue
        fi
        pkg_installed "$PKG_MGR" "$name" && continue
        MISS+=("$name")
    done
}

do_packages() {
    PKG_MGR=""
    if command -v pacman  >/dev/null 2>&1; then PKG_MGR=pacman
    elif command -v apt-get >/dev/null 2>&1; then PKG_MGR=apt
    elif command -v brew    >/dev/null 2>&1; then PKG_MGR=brew
    else
        echo "📦 No pacman, apt or brew found; skipping the package check."
        return 0
    fi
    setup_sudo

    local want=("${PKGS_CLI[@]}")
    [[ "$MODE" == "full" && "$OS" == "linux" ]] && want+=("${PKGS_TERM[@]}")
    triage "${want[@]}"

    (( ${#UNAVAIL[@]} )) && \
        echo "📦 Not packaged for $PKG_MGR, skipping: ${UNAVAIL[*]}"

    if (( ${#MISS[@]} == 0 )); then
        echo "📦 All packages present."
        return 0
    fi

    if (( ! PACKAGES )); then
        echo "📦 Missing ${#MISS[@]} package(s): ${MISS[*]}"
        echo "   install with: $0 --packages"
        return 0
    fi

    echo "📦 Installing ${#MISS[@]} missing package(s) with $PKG_MGR..."
    case "$PKG_MGR" in
        # Not --noconfirm interactively: this is the one step that touches the
        # system outside $HOME, so it should be seen before it happens. Headless
        # there is nobody to see it, and a prompt would hang the boot.
        pacman)
            if [[ -t 0 ]]; then $SUDO pacman -S --needed "${MISS[@]}"
            else               $SUDO pacman -S --needed --noconfirm "${MISS[@]}"; fi ;;
        # The image layers end with `rm -rf /var/lib/apt/lists/*`, so an update is
        # mandatory or every name is "unable to locate". Gated on there being
        # something to install, so the steady state costs nothing. The lock
        # timeout matters: a blocked apt on a startup script hangs it forever.
        # DEBIAN_FRONTEND must be inside env, since sudo resets the environment.
        apt)
            $SUDO env DEBIAN_FRONTEND=noninteractive \
                apt-get -o DPkg::Lock::Timeout=60 update -qq
            $SUDO env DEBIAN_FRONTEND=noninteractive \
                apt-get -o DPkg::Lock::Timeout=60 install -y --no-install-recommends "${MISS[@]}" ;;
        brew) brew install "${MISS[@]}" ;;
    esac
}

do_packages

echo "🔗 Linking CLI configs..."
link zshrc/.zshenv           "$HOME/.zshenv"
link zshrc/.zshrc            "$HOME/.zshrc"
link tmux_conf/.tmux.conf    "$HOME/.tmux.conf"
link starship/starship.toml  "$HOME/.config/starship.toml"
link atuin/config.toml       "$HOME/.config/atuin/config.toml"
link dex/config.toml         "$HOME/.config/dex/config.toml"
link bin/tmux-session-manager.sh "$HOME/.config/tms/tmux-session-manager.sh"

# The config names the server; the bearer token is deliberately not in it (or
# in this repo at all — see dex/config.toml). Same shape as the atuin key
# check below: report once, non-interactively, and move on.
if [[ ! -s "$HOME/.config/dex/token" ]]; then
    echo "  ℹ️  no ~/.config/dex/token yet; dex CLI commands will get 401 until you make one:"
    echo "       echo '<your dex bearer token>' > ~/.config/dex/token && chmod 600 ~/.config/dex/token"
fi

for f in "$SCRIPT_DIR"/tms_projects/*.conf; do
    [[ -e "$f" ]] || continue
    link "tms_projects/$(basename "$f")" "$HOME/.config/tms/projects/$(basename "$f")"
done

if [[ "$MODE" == "full" ]]; then
    # Utility scripts go on PATH so nothing needs to know where this repo is
    # cloned. All of them read sysfs or plain CLI tools and degrade with a
    # message rather than a traceback when the hardware is not there -- but
    # sysfs itself is Linux, so a Mac gets none of them.
    if [[ "$OS" == "linux" ]]; then
        echo "🔗 Linking scripts into ~/.local/bin..."
        for f in "$SCRIPT_DIR"/bin/*.sh; do
            [[ -e "$f" ]] || continue
            link "bin/$(basename "$f")" "$HOME/.local/bin/$(basename "$f")"
        done
    fi

    # Terminals. Catppuccin Mocha, standing on their own: each pulls the neu
    # palette in through an OPTIONAL include that matches nothing until the rgtv
    # dotfiles are installed, so there is no half-themed state and nothing to
    # undo when that repo comes off. NOTHING here may name a file only that repo
    # ships -- a machine with this repo alone (work) has to come up clean.
    echo "🔗 Linking terminal configs..."
    link kitty/kitty.conf         "$HOME/.config/kitty/kitty.conf"
    link alacritty/alacritty.toml "$HOME/.config/alacritty/alacritty.toml"
    link ghostty/config           "$HOME/.config/ghostty/config"
fi

echo "🧹 Pruning links left by older revisions of this repo..."
prune_stale_links "$HOME" "$HOME/.local/bin" "$HOME/.config" \
    "$HOME/.config/atuin" "$HOME/.config/dex" \
    "$HOME/.config/tms" "$HOME/.config/tms/projects" \
    "$HOME/.config/kitty" "$HOME/.config/alacritty" \
    "$HOME/.config/ghostty" "$HOME/.config/ghostty/themes"

# --- Bootstrap ---------------------------------------------------------------
# Best-effort: a workspace must still start with no network, so every step warns
# and moves on instead of failing the script. Runs after linking so configs land
# even offline.
#
# These are the tools no package manager here carries (PKG_BOOT above names
# them). They install into $HOME rather than /usr, which is what makes them worth
# doing on every run: a Coder workspace container is destroyed and recreated on
# every start, and only /home survives -- so a $HOME install is paid once where
# an apt install is paid forever.

bootstrap_starship() {
    if command -v starship >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/starship" ]]; then
        return 0
    fi
    mkdir -p "$HOME/.local/bin"
    if curl -sSfL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"; then
        echo "  ✅ starship installed to ~/.local/bin"
    else
        echo "  ⚠️  starship install failed"
    fi
}

bootstrap_atuin() {
    if command -v atuin >/dev/null 2>&1 || [[ -x "$HOME/.atuin/bin/atuin" ]]; then
        return 0
    fi
    # --non-interactive is load-bearing, not cosmetic: without it the installer
    # probes for a tty with `exec 3</dev/tty`, and under dash -- which is /bin/sh
    # on Debian/Ubuntu, and what a Coder startup_script runs -- a redirection
    # error on `exec` kills the shell outright. The flag makes it skip the probe.
    if curl -LsSf https://setup.atuin.sh | sh -s -- --non-interactive; then
        echo "  ✅ atuin installed to ~/.atuin/bin"
        # The history db is useless without a key, and `atuin init` exits 1
        # without one -- which silently costs you Ctrl+R on every new shell.
        # See the atuin section of the README.
        if [[ ! -f "$HOME/.local/share/atuin/key" ]]; then
            echo "  ℹ️  no atuin key yet; Ctrl+R falls back to zsh until you make one:"
            echo "       openssl rand 32 | base64 -w0 > ~/.local/share/atuin/key"
        fi
    else
        echo "  ⚠️  atuin install failed"
    fi
}

bootstrap_tpm() {
    if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
        return 0
    fi
    if ! command -v git >/dev/null 2>&1; then
        echo "  ⚠️  git missing; skipping TPM"
        return 0
    fi
    if ! git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"; then
        echo "  ⚠️  TPM clone failed"
        return 0
    fi
    # install_plugins needs a live server that has sourced the conf; without one
    # it exits having done nothing. Spin a throwaway detached session for it and
    # kill only that session, so a restored resurrect/continuum session is safe.
    if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]] && command -v tmux >/dev/null 2>&1; then
        tmux new-session -d -s _tpm_install 2>/dev/null || true
        "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 \
            && echo "  ✅ TPM installed, plugins synced" \
            || echo "  ✅ TPM installed (run prefix+I inside tmux for plugins)"
        tmux kill-session -t _tpm_install 2>/dev/null || true
    else
        echo "  ✅ TPM installed"
    fi
}

# Unconditional, not minimal-only: the desktop needs starship and atuin exactly
# as much as a workspace does, and each function is a no-op once satisfied.
if (( BOOTSTRAP )); then
    echo "🛠️  Bootstrapping tools (best-effort)..."
    bootstrap_starship || echo "  ⚠️  starship bootstrap failed"
    bootstrap_atuin    || echo "  ⚠️  atuin bootstrap failed"
    bootstrap_tpm      || echo "  ⚠️  TPM bootstrap failed"
fi

write_stamp personal

echo "✅ Dotfiles installation complete ($MODE)."
