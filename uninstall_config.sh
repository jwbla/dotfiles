#!/bin/bash

echo "⚠️  This will remove all symlinks created by stow for your dotfiles."
read -p "Are you sure you want to proceed? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Uninstallation aborted."
    exit 1
fi

echo "🗑️  Removing config symlinks using stow..."

# Function to safely run stow commands with error checking
run_stow_uninstall() {
    local package="$1"
    local target="$2"
    local description="$3"
    
    echo "  Removing $description..."
    if stow -D -t "$target" "$package" >/dev/null 2>&1; then
        echo "  ✅ Successfully removed $description"
    else
        echo "  ⚠️  Warning: $description may not have been installed or already removed"
    fi
}

# Remove config directory symlinks (matching install script structure)
run_stow_uninstall "hypr" "$HOME/.config/hypr" "hypr config"
run_stow_uninstall "waybar" "$HOME/.config/waybar" "waybar config"
run_stow_uninstall "kitty" "$HOME/.config/kitty" "kitty config"
run_stow_uninstall "alacritty" "$HOME/.config/alacritty" "alacritty config"
run_stow_uninstall "wofi" "$HOME/.config/wofi" "wofi config"
run_stow_uninstall "ghostty" "$HOME/.config/ghostty" "ghostty config"
run_stow_uninstall "starship" "$HOME/.config" "starship config"

# Remove home directory symlinks
run_stow_uninstall "tmux_conf" "$HOME" "tmux config"
run_stow_uninstall "zshrc" "$HOME" "zsh config"

# Remove newsboat config file symlinks individually
echo "  Removing newsboat config files..."
NEWSBOAT_DIR="$HOME/.newsboat"
for file in config dark urls; do
    target="$NEWSBOAT_DIR/$file"
    if [[ -L "$target" ]]; then
        rm "$target"
        echo "    ✅ Removed $file"
    elif [[ -e "$target" ]]; then
        echo "    ⚠️  $file exists but is not a symlink, skipping..."
    fi
done
echo "  ✅ Successfully removed newsboat config"

# Remove dunst config file symlinks individually
echo "  Removing dunst config files..."
DUNST_DIR="$HOME/.config/dunst"
for file in dunstrc; do
    target="$DUNST_DIR/$file"
    if [[ -L "$target" ]]; then
        rm "$target"
        echo "    ✅ Removed $file"
    elif [[ -e "$target" ]]; then
        echo "    ⚠️  $file exists but is not a symlink, skipping..."
    fi
done
echo "  ✅ Successfully removed dunst config"

# Remove tms project config symlinks
echo "  Removing tms project configs..."
TMS_DIR="$HOME/.config/tms/projects"
if [[ -d "$TMS_DIR" ]]; then
    for target in "$TMS_DIR"/*.conf; do
        [[ -e "$target" ]] || continue
        file="$(basename "$target")"
        if [[ -L "$target" ]]; then
            rm "$target"
            echo "    ✅ Removed $file"
        elif [[ -e "$target" ]]; then
            echo "    ⚠️  $file exists but is not a symlink, skipping..."
        fi
    done
fi
echo "  ✅ Successfully removed tms project configs"

# Remove empty directories in ~/.config
echo "🧹 Cleaning up empty directories..."
find "$HOME/.config" -type d -empty -delete 2>/dev/null || true

echo "✅ Config uninstallation complete."
