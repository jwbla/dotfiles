#!/bin/bash

echo Backing up config
cp -r ~/.config/hypr ~/dev/dotfiles
cp -r ~/.config/waybar ~/dev/dotfiles
cp -r ~/.config/kitty ~/dev/dotfiles
cp -r ~/.config/alacritty ~/dev/dotfiles
cp ~/.tmux.conf ~/dev/dotfiles/.tmux.conf
cp ~/.zshrc ~/dev/dotfiles/.zshrc
cp ~/.rgtv.env ~/dev/dotfiles/.rgtv.env
