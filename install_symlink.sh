
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

# Install home directory symlinks
run_stow_install "tmux_conf" "$HOME" "tmux config"
run_stow_install "zshrc" "$HOME" "zsh config"
run_stow_install "rgtv_env" "$HOME" "rgtv environment"

echo "✅ Config installation complete."
