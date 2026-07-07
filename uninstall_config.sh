#!/usr/bin/env bash
# Removes every symlink that points into this repo and restores any
# <file>.predotfiles backups the installer made.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        *) echo "usage: $0 [-y|--yes]" >&2; exit 2 ;;
    esac
done

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
    "$HOME/.config/hypr"
    "$HOME/.config/waybar"
    "$HOME/.config/kitty"
    "$HOME/.config/alacritty"
    "$HOME/.config/wofi"
    "$HOME/.config/ghostty"
    "$HOME/.config/dunst"
    "$HOME/.config/tms"
    "$HOME/.config/tms/projects"
    "$HOME/.newsboat"
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
    "$HOME/.config/hypr" \
    "$HOME/.config/waybar" \
    "$HOME/.config/kitty" \
    "$HOME/.config/alacritty" \
    "$HOME/.config/wofi" \
    "$HOME/.config/ghostty" \
    "$HOME/.config/dunst" \
    "$HOME/.newsboat"
do
    if [[ -d "$dir" ]]; then
        rmdir --ignore-fail-on-non-empty "$dir"
    fi
done

echo "✅ Config uninstallation complete."
