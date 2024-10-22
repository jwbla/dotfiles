#!/bin/bash

echo Backing up config
cp -r ~/.config/hypr ~/dev/dotfiles/hyprland
cp -r ~/.config/waybar ~/dev/dotfiles/waybar
cp -r ~/.config/kitty ~/dev/dotfiles/kitty
cp -r ~/.config/alacritty ~/dev/dotfiles/alacritty
cp ~/.tmux.conf ~/dev/dotfiles/.tmux.conf
cp ~/.zshrc ~/dev/dotfiles/.zshrc
cp ~/.rgtv.env ~/dev/dotfiles/.rgtv.env
