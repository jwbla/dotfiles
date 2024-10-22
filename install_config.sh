#!/bin/bash

# this should be run from the repository!!!

echo Installing config

cp -r ~/dev/dotfiles/hypr ~/.config
cp -r ~/dev/dotfiles/waybar ~/.config
cp -r ~/dev/dotfiles/kitty ~/.config
cp ~/dev/dotfiles/alacritty ~/.config/alacritty
cp ~/dev/dotfiles/.tmux.conf ~/.tmux.conf 
cp ~/dev/dotfiles/.zshrc ~/.zshrc
cp ~/dev/dotfiles/.rgtv.env ~/.rgtv.env
