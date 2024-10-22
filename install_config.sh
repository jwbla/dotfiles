#!/bin/bash

# this should be run from the repository!!!

echo Installing config

cp -r ~/dev/dotfiles/hyprland ~/.config/hypr 
cp -r ~/dev/dotfiles/waybar ~/.config/waybar
cp -r ~/dev/dotfiles/kitty ~/.config/kitty
cp -r ~/dev/dotfiles/alacritty ~/.config/alacritty
cp ~/dev/dotfiles/.tmux.conf ~/.tmux.conf 
cp ~/dev/dotfiles/.zshrc ~/.zshrc
cp ~/dev/dotfiles/.rgtv.env ~/.rgtv.env
