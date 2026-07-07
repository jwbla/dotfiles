# Loaded by every zsh invocation (interactive, non-interactive, login).
# Put env vars here that must be visible to processes launched outside a login
# shell (e.g. waybar widgets started by Hyprland).

# typeset -U keeps $path duplicate-free even though .zshenv runs for every
# nested shell.
typeset -U path
path=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.opencode/bin" $path)
export PATH

export BROWSER=librewolf

# Share one Cargo build target dir across all Rust projects on this machine.
# Cargo's fingerprinting isolates per-crate artifacts inside this dir.
export CARGO_TARGET_DIR="$HOME/.cache/cargo-target"

# Pull in private env (API keys, etc.) from the rgtv-domain repo if installed.
# Graceful no-op on machines without the private repo stowed.
[[ -f "$HOME/.rgtv/.rgtv.env" ]] && source "$HOME/.rgtv/.rgtv.env"
