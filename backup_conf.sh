#!/bin/bash

echo Backing up config
cp -r ~/.config/hypr ~/dev/dotfiles
cp -r ~/.config/waybar ~/dev/dotfiles
cp -r ~/.config/kitty ~/dev/dotfiles
cp ~/.config/alacritty ~/dev/dotfiles/alacritty
cp ~/.tmux.conf ~/dev/dotfiles/.tmux.conf
cp ~/.zshrc ~/dev/dotfiles/.zshrc
cp ~/.rgtv.env ~/dev/dotfiles/.rgtv.env
