#!/usr/bin/env bash
# Portable dotfiles: zsh, tmux, atuin, the tms session manager, and the base
# terminal configs. Runs on every machine the operator touches -- the Arch
# desktop, a Mac, a Coder workspace -- and must be idempotent and prompt-free on
# all of them, because workspaces run it non-interactively on every start.
#
#   minimal   the portable CLI. macOS and Coder workspaces get this.
#   full      minimal + the GUI terminal configs and the laptop scripts.
#             Linux only.
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
      echo "installed=$(date -Is)"
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

# Default full unless this is positively not a graphical Linux box: wrong-full in
# a workspace links a couple of terminal configs nothing reads, wrong-minimal on
# the desktop silently drops them.
if [[ -z "$MODE" ]]; then
    if [[ "$OS" != "linux" ]]; then
        MODE=minimal
    elif [[ "${CODER:-}" == "true" || -n "${CODER_AGENT_URL:-}" || "$SCRIPT_DIR" == */coderv2/dotfiles* ]]; then
        MODE=minimal
    else
        MODE=full
    fi
fi

if [[ "$MODE" == "full" && "$OS" != "linux" ]]; then
    echo "⚠️  --full is Linux-only (this is $OS); falling back to minimal."
    MODE=minimal
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

# ---------------------------------------------------------------- packages --
# Only what this repo's configs actually invoke is listed -- if nothing here
# shells out to it, it does not belong.
PKGS_CLI_ARCH=(zsh tmux starship atuin jq fzf eza zoxide neovim git)
PKGS_CLI_BREW=(zsh tmux starship atuin jq fzf eza zoxide neovim git)

# Terminals, on a Linux desktop only. The configs are linked either way; these
# are what reads them.
PKGS_TERM_ARCH=(ghostty kitty)

missing_pkgs() {
    local -n _list=$1
    local out=() p
    for p in "${_list[@]}"; do
        case "$PKG_MGR" in
            pacman) pacman -Qq "$p" &>/dev/null && continue ;;
            brew)   brew list --versions "$p" &>/dev/null && continue ;;
        esac
        # A same-named binary already on PATH means the need is met however it
        # got there -- starship and atuin arrive via the bootstrap below, and
        # zoxide/eza are often cargo-installed.
        command -v "$p" >/dev/null 2>&1 && continue
        out+=("$p")
    done
    printf '%s\n' "${out[@]:-}"
}

do_packages() {
    PKG_MGR=""
    command -v pacman >/dev/null 2>&1 && PKG_MGR=pacman
    [[ -z "$PKG_MGR" ]] && command -v brew >/dev/null 2>&1 && PKG_MGR=brew
    if [[ -z "$PKG_MGR" ]]; then
        echo "📦 No pacman or brew found; skipping the package check."
        return 0
    fi

    local want=()
    if [[ "$PKG_MGR" == "pacman" ]]; then
        want+=("${PKGS_CLI_ARCH[@]}")
        [[ "$MODE" == "full" ]] && want+=("${PKGS_TERM_ARCH[@]}")
    else
        want+=("${PKGS_CLI_BREW[@]}")
    fi

    local miss
    mapfile -t miss < <(missing_pkgs want)
    # mapfile on empty input still yields one empty element
    [[ ${#miss[@]} -eq 1 && -z "${miss[0]}" ]] && miss=()

    if [[ ${#miss[@]} -eq 0 ]]; then
        echo "📦 All packages present."
        return 0
    fi

    if (( PACKAGES )); then
        echo "📦 Installing ${#miss[@]} missing package(s) with $PKG_MGR..."
        case "$PKG_MGR" in
            # Not --noconfirm: this is the one step that touches the system
            # outside $HOME, so it should be seen before it happens.
            pacman) sudo pacman -S --needed "${miss[@]}" ;;
            brew)   brew install "${miss[@]}" ;;
        esac
    else
        echo "📦 Missing ${#miss[@]} package(s): ${miss[*]}"
        case "$PKG_MGR" in
            pacman) echo "   install with: $0 --packages   (or: sudo pacman -S --needed ${miss[*]})" ;;
            brew)   echo "   install with: $0 --packages   (or: brew install ${miss[*]})" ;;
        esac
    fi
}

do_packages

echo "🔗 Linking CLI configs..."
link zshrc/.zshenv           "$HOME/.zshenv"
link zshrc/.zshrc            "$HOME/.zshrc"
link tmux_conf/.tmux.conf    "$HOME/.tmux.conf"
link starship/starship.toml  "$HOME/.config/starship.toml"
link atuin/config.toml       "$HOME/.config/atuin/config.toml"
link bin/tmux-session-manager.sh "$HOME/.config/tms/tmux-session-manager.sh"

for f in "$SCRIPT_DIR"/tms_projects/*.conf; do
    [[ -e "$f" ]] || continue
    link "tms_projects/$(basename "$f")" "$HOME/.config/tms/projects/$(basename "$f")"
done

if [[ "$MODE" == "full" ]]; then
    # Utility scripts go on PATH so nothing needs to know where this repo is
    # cloned. All of them read sysfs or plain CLI tools and degrade with a
    # message rather than a traceback when the hardware is not there.
    echo "🔗 Linking scripts into ~/.local/bin..."
    for f in "$SCRIPT_DIR"/bin/*.sh; do
        [[ -e "$f" ]] || continue
        link "bin/$(basename "$f")" "$HOME/.local/bin/$(basename "$f")"
    done

    # Terminals. Catppuccin Mocha, standing on their own: each pulls the neu
    # palette in through an OPTIONAL include that matches nothing until the rgtv
    # dotfiles are installed, so there is no half-themed state and nothing to
    # undo when that repo comes off.
    echo "🔗 Linking terminal configs..."
    link kitty/kitty.conf         "$HOME/.config/kitty/kitty.conf"
    link alacritty/alacritty.toml "$HOME/.config/alacritty/alacritty.toml"
    link ghostty/config           "$HOME/.config/ghostty/config"
fi

# --- Bootstrap ---------------------------------------------------------------
# Best-effort: a workspace must still start with no network, so every step warns
# and moves on instead of failing the script. Runs after linking so configs land
# even offline. starship and TPM are not packaged everywhere, which is exactly
# why they are fetched here rather than listed above.

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

bootstrap_tpm() {
    if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
        return 0
    fi
    if ! command -v git >/dev/null 2>&1; then
        echo "  ⚠️  git missing; skipping TPM"
        return 0
    fi
    if git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"; then
        if command -v tmux >/dev/null 2>&1; then
            "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
        fi
        echo "  ✅ TPM installed"
    else
        echo "  ⚠️  TPM clone failed"
    fi
}

if [[ "$MODE" == "minimal" && "$BOOTSTRAP" == "1" ]]; then
    echo "🛠️  Bootstrapping tools (best-effort)..."
    bootstrap_starship || echo "  ⚠️  starship bootstrap failed"
    bootstrap_tpm      || echo "  ⚠️  TPM bootstrap failed"
fi

write_stamp personal

echo "✅ Dotfiles installation complete ($MODE)."
