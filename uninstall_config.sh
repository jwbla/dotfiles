#!/bin/bash

echo "⚠️  This will remove all symlinks created by stow for your dotfiles."
read -p "Are you sure you want to proceed? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Uninstallation aborted."
    exit 1
fi

echo "Removing config symlinks using stow..."

stow -D -d ~/dev/dotfiles -t ~/.config hypr
stow -D -d ~/dev/dotfiles -t ~/.config waybar
stow -D -d ~/dev/dotfiles -t ~/.config kitty
stow -D -d ~/dev/dotfiles -t ~/.config alacritty
stow -D -d ~/dev/dotfiles -t ~/.config wofi
stow -D -d ~/dev/dotfiles -t ~ .tmux.conf
stow -D -d ~/dev/dotfiles -t ~ .zshrc
stow -D -d ~/dev/dotfiles -t ~ .rgtv.env

# Optional: Remove empty directories in ~/.config
find ~/.config -type d -empty -delete

echo "✅ Config uninstallation complete."
