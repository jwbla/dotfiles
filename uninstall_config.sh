#!/usr/bin/env bash
# Removes every symlink that points into this repo and restores any
# <file>.predotfiles backups the installer made.
#
# The rgtv dotfiles install ON TOP of these, so teardown runs in the reverse
# order of install: this script refuses to start while that half is still
# installed, because removing the base leaves its overrides -- ~/.tmux-neu.conf,
# kitty's neu.conf, the systemd units -- pointing at a setup whose other half is
# gone. --force says do it anyway.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"

ASSUME_YES=0
FORCE=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        --force) FORCE=1 ;;
        *) echo "usage: $0 [-y|--yes] [--force]" >&2; exit 2 ;;
    esac
done

read_stamp() {
    [[ -f "$STAMP_DIR/$1.stamp" ]] || return 1
    sed -n "s/^$2=//p" "$STAMP_DIR/$1.stamp"
}

# A stamp is only believed while the checkout it names still exists -- a deleted
# repo must not be able to block this one forever.
peer_installed() {
    local repo
    repo="$(read_stamp "$1" repo)" || return 1
    [[ -n "$repo" && -d "$repo/.git" ]]
}

if peer_installed rgtv; then
    rgtv_repo="$(read_stamp rgtv repo)"
    echo "⚠️  The rgtv dotfiles are installed on top of these ($rgtv_repo)." >&2
    echo "   Uninstall them first:  $rgtv_repo/uninstall_config.sh" >&2
    if (( ! FORCE )); then
        echo "   (or re-run with --force to remove this half anyway)" >&2
        exit 1
    fi
    echo "   --force given; continuing and leaving the rgtv links dangling." >&2
fi

echo "⚠️  This will remove all symlinks pointing into $SCRIPT_DIR."
if (( ! ASSUME_YES )); then
    read -p "Are you sure you want to proceed? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "❌ Uninstallation aborted."
        exit 1
    fi
fi

echo "🗑️  Removing dotfiles symlinks..."

# Every directory install.sh links into, scanned at depth 1. Matching on the
# resolved target ("points into the repo") instead of a link map means new
# packages never need to be added here unless they use a new directory.
SCAN_DIRS=(
    "$HOME"
    "$HOME/.local/bin"
    "$HOME/.config"
    "$HOME/.config/atuin"
    "$HOME/.config/tms"
    "$HOME/.config/tms/projects"
    "$HOME/.config/kitty"
    "$HOME/.config/alacritty"
    "$HOME/.config/ghostty"
)

remove_repo_links() {
    local dir="$1" l target
    if [[ ! -d "$dir" ]]; then
        return 0
    fi
    while IFS= read -r l; do
        target="$(readlink -f "$l" 2>/dev/null || true)"
        if [[ "$target" == "$SCRIPT_DIR"/* ]]; then
            rm "$l"
            echo "  ✅ Removed $l"
            if [[ -e "$l.predotfiles" ]]; then
                mv "$l.predotfiles" "$l"
                echo "  ℹ️  Restored $l from backup"
            fi
        fi
    done < <(find "$dir" -maxdepth 1 -type l)
}

for dir in "${SCAN_DIRS[@]}"; do
    remove_repo_links "$dir"
done

# Clean up only the directories this repo creates (deepest first); leave
# anything non-empty alone.
echo "🧹 Cleaning up empty directories..."
for dir in \
    "$HOME/.config/tms/projects" \
    "$HOME/.config/tms" \
    "$HOME/.config/atuin" \
    "$HOME/.config/kitty" \
    "$HOME/.config/alacritty" \
    "$HOME/.config/ghostty"
do
    if [[ -d "$dir" ]]; then
        rmdir --ignore-fail-on-non-empty "$dir"
    fi
done

rm -f "$STAMP_DIR/personal.stamp"

echo "✅ Config uninstallation complete."
