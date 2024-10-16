#!/bin/bash

echo Backing up config
cp ~/.config/hypr/* ~/dev/dotfiles/hyprland
cp ~/.config/waybar/* ~/dev/dotfiles/waybar
cp ~/.config/kitty/* ~/dev/dotfiles/kitty
cp ~/.config/alacritty/* ~/dev/dotfiles/alacritty
cp ~/.tmux.conf ~/dev/dotfiles/.tmux.conf
cp ~/.zshrc ~/dev/dotfiles/.zshrc
cp ~/.rgtv.env ~/dev/dotfiles/.rgtv.env
