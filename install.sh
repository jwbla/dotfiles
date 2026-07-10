#!/usr/bin/env bash
# Coder-compatible entry point: Coder workspaces clone this repo (to
# ~/.config/coderv2/dotfiles) and run install.sh non-interactively on every
# workspace start, so everything here must be idempotent and prompt-free.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE=""
BOOTSTRAP=1
for arg in "$@"; do
    case "$arg" in
        --minimal) MODE=minimal ;;
        --full) MODE=full ;;
        --no-bootstrap) BOOTSTRAP=0 ;;
        *) echo "usage: $0 [--minimal|--full] [--no-bootstrap]" >&2; exit 2 ;;
    esac
done

# Default full unless a Coder workspace is positively detected: wrong-full in a
# workspace just links unused configs, wrong-minimal on the desktop silently
# drops the hypr/waybar links.
if [[ -z "$MODE" ]]; then
    if [[ "${CODER:-}" == "true" || -n "${CODER_AGENT_URL:-}" || "$SCRIPT_DIR" == */coderv2/dotfiles* ]]; then
        MODE=minimal
    else
        MODE=full
    fi
fi

echo "📦 Installing dotfiles ($MODE mode) from $SCRIPT_DIR"

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

echo "🔗 Linking CLI configs..."
link zshrc/.zshenv           "$HOME/.zshenv"
link zshrc/.zshrc            "$HOME/.zshrc"
link tmux_conf/.tmux.conf    "$HOME/.tmux.conf"
link starship/starship.toml  "$HOME/.config/starship.toml"
link bin/tmux-session-manager.sh "$HOME/.config/tms/tmux-session-manager.sh"

if [[ "$MODE" == "full" ]]; then
    # Desktop utility scripts go on PATH so nothing (hyprland binds, other
    # scripts) needs to know where this repo is cloned.
    echo "🔗 Linking scripts into ~/.local/bin..."
    for f in "$SCRIPT_DIR"/bin/*.sh; do
        link "bin/$(basename "$f")" "$HOME/.local/bin/$(basename "$f")"
    done

    echo "🔗 Linking desktop configs..."
    # hyprland.conf was replaced by hyprland.lua (Hyprland >= 0.55)
    old="$HOME/.config/hypr/hyprland.conf"
    if [[ -L "$old" && "$(readlink -f "$old" 2>/dev/null || true)" == "$SCRIPT_DIR"/* ]]; then
        rm "$old" && echo "  🧹 removed stale $old (replaced by hyprland.lua)"
    fi
    for f in hyprland.lua hypridle.conf hyprlock.conf hyprpaper.conf; do
        link "hypr/$f" "$HOME/.config/hypr/$f"
    done
    for f in "$SCRIPT_DIR"/waybar/*; do
        link "waybar/$(basename "$f")" "$HOME/.config/waybar/$(basename "$f")"
    done
    link kitty/kitty.conf         "$HOME/.config/kitty/kitty.conf"
    link alacritty/alacritty.toml "$HOME/.config/alacritty/alacritty.toml"
    link wofi/config              "$HOME/.config/wofi/config"
    link wofi/style.css           "$HOME/.config/wofi/style.css"
    link ghostty/config           "$HOME/.config/ghostty/config"
    link dunst/dunstrc            "$HOME/.config/dunst/dunstrc"
    for f in config dark urls; do
        link ".newsboat/$f" "$HOME/.newsboat/$f"
    done
    for f in "$SCRIPT_DIR"/tms_projects/*.conf; do
        link "tms_projects/$(basename "$f")" "$HOME/.config/tms/projects/$(basename "$f")"
    done
fi

# --- Bootstrap (workspace mode only) -----------------------------------------
# Best-effort: a workspace must still start with no network, so every step
# warns and moves on instead of failing the script. Runs after linking so
# configs land even offline.

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

echo "✅ Dotfiles installation complete."
