#!/bin/bash

echo Deleting dirs used by dotfiles...

rm -rf ~/.config/hypr
rm -rf ~/.config/waybar
rm -rf ~/.config/kitty
rm -rf ~/.config/alacritty
rm -rf ~/.config/wofi

rm ~/.tmux.conf
rm ~/.zshrc
rm ~/.rgtv.env
