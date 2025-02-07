
#!/bin/bash

# this should be run from the repository!!!

echo Installing config with symlinks...

echo Creating dirs in ~/.config
mkdir ~/.config/hypr
mkdir ~/.config/waybar
mkdir ~/.config/kitty
mkdir ~/.config/alacritty
mkdir ~/.config/wofi

echo Creating symlinks with stow...

stow hypr -t ~/.config/hypr hypr
stow waybar -t ~/.config/waybar waybar
stow kitty -t ~/.config/kitty kitty
stow alacritty -t ~/.config/alacritty alacritty
stow wofi -t ~/.config/wofi wofi

stow tmux_conf -t ~ tmux_conf
stow zshrc -t ~ zshrc
stow rgtv_env -t ~ rgtv_env
