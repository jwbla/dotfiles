
#!/bin/bash

echo "📦 Installing config with symlinks..."

echo "📁 Creating directories in ~/.config"
mkdir -p ~/.config/hypr
mkdir -p ~/.config/waybar
mkdir -p ~/.config/kitty
mkdir -p ~/.config/alacritty
mkdir -p ~/.config/wofi
mkdir -p ~/.config/ghostty
mkdir -p ~/.config/starship
mkdir -p ~/.config/dunst
mkdir -p ~/.newsboat

echo "🔗 Creating symlinks with stow..."

# Function to safely run stow commands with error checking
run_stow_install() {
    local package="$1"
    local target="$2"
    local description="$3"
    
    echo "  Installing $description..."
    if stow -t "$target" "$package" >/dev/null 2>&1; then
        echo "  ✅ Successfully installed $description"
    else
        echo "  ❌ Failed to install $description"
        return 1
    fi
}

# Install config directory symlinks
run_stow_install "hypr" "$HOME/.config/hypr" "hypr config"
run_stow_install "waybar" "$HOME/.config/waybar" "waybar config"
run_stow_install "kitty" "$HOME/.config/kitty" "kitty config"
run_stow_install "alacritty" "$HOME/.config/alacritty" "alacritty config"
run_stow_install "wofi" "$HOME/.config/wofi" "wofi config"
run_stow_install "ghostty" "$HOME/.config/ghostty" "ghostty config"
run_stow_install "starship" "$HOME/.config" "starship config"

# Install newsboat config files individually (not using stow to avoid symlinking the directory)
echo "  Installing newsboat config files..."
NEWSBOAT_DIR="$HOME/.newsboat"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$NEWSBOAT_DIR"

# Function to create symlink for a newsboat file
link_newsboat_file() {
    local file="$1"
    local source="$DOTFILES_DIR/.newsboat/$file"
    local target="$NEWSBOAT_DIR/$file"
    
    if [[ -f "$source" ]]; then
        if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
            echo "    ⚠️  $file already exists and is not a symlink, skipping..."
            return 1
        elif [[ -L "$target" ]]; then
            rm "$target"
        fi
        ln -s "$source" "$target"
        echo "    ✅ Linked $file"
        return 0
    else
        echo "    ❌ Source file $source not found"
        return 1
    fi
}

link_newsboat_file "config"
link_newsboat_file "dark"
link_newsboat_file "urls"
echo "  ✅ Successfully installed newsboat config"

# Install dunst config files individually (not using stow to avoid symlinking the directory)
echo "  Installing dunst config files..."
DUNST_DIR="$HOME/.config/dunst"
mkdir -p "$DUNST_DIR"

# Function to create symlink for a dunst file
link_dunst_file() {
    local file="$1"
    local source="$DOTFILES_DIR/dunst/$file"
    local target="$DUNST_DIR/$file"
    
    if [[ -f "$source" ]]; then
        if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
            echo "    ⚠️  $file already exists and is not a symlink, skipping..."
            return 1
        elif [[ -L "$target" ]]; then
            rm "$target"
        fi
        ln -s "$source" "$target"
        echo "    ✅ Linked $file"
        return 0
    else
        echo "    ❌ Source file $source not found"
        return 1
    fi
}

link_dunst_file "dunstrc"
echo "  ✅ Successfully installed dunst config"

# Install home directory symlinks
run_stow_install "tmux_conf" "$HOME" "tmux config"
run_stow_install "zshrc" "$HOME" "zsh config"

echo "✅ Config installation complete."
