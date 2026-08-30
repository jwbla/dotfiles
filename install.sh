#!/usr/bin/env bash
# Runs on three kinds of machine and must be idempotent and prompt-free on all of
# them, because Coder workspaces clone this repo (to ~/.config/coderv2/dotfiles)
# and run it non-interactively on every workspace start.
#
#   minimal   portable CLI only -- zsh, tmux, starship, atuin, tms.
#             macOS and Coder workspaces get this: none of the rest applies.
#   full      minimal + the Linux desktop (hyprland, quickshell, the neu theme,
#             terminals, GTK/Qt). Linux only.
#
# Package installation is OPT-IN (`--packages`). Without it the script only
# reports what is missing, so a workspace start never blocks on a package
# manager and nothing is installed behind your back.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE=""
BOOTSTRAP=1
PACKAGES=0
GENERATE=1
for arg in "$@"; do
    case "$arg" in
        --minimal) MODE=minimal ;;
        --full) MODE=full ;;
        --no-bootstrap) BOOTSTRAP=0 ;;
        --packages) PACKAGES=1 ;;
        --no-generate) GENERATE=0 ;;
        -h|--help)
            awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"
            echo
            echo "usage: $0 [--minimal|--full] [--packages] [--no-generate] [--no-bootstrap]"
            exit 0 ;;
        *) echo "usage: $0 [--minimal|--full] [--packages] [--no-generate] [--no-bootstrap]" >&2; exit 2 ;;
    esac
done

case "$(uname -s)" in
    Darwin) OS=macos ;;
    Linux)  OS=linux ;;
    *)      OS=other ;;
esac

# Default full unless this is positively NOT a Linux desktop: wrong-full in a
# workspace just links unused configs, wrong-minimal on the desktop silently
# drops the hypr/quickshell links.
if [[ -z "$MODE" ]]; then
    if [[ "$OS" != "linux" ]]; then
        MODE=minimal
    elif [[ "${CODER:-}" == "true" || -n "${CODER_AGENT_URL:-}" || "$SCRIPT_DIR" == */coderv2/dotfiles* ]]; then
        MODE=minimal
    else
        MODE=full
    fi
fi

# The desktop half is Hyprland/Wayland-specific. Asking for it on a Mac would
# scatter ~/.config/hypr, ~/.config/quickshell and friends into a home that can
# never use them.
if [[ "$MODE" == "full" && "$OS" != "linux" ]]; then
    echo "⚠️  --full is Linux-only (this is $OS); falling back to minimal."
    MODE=minimal
fi

echo "📦 Installing dotfiles ($MODE mode, $OS) from $SCRIPT_DIR"

# link <repo-relative-src> <absolute-dst>
# A pre-existing real file (or directory) at dst is moved to dst.predotfiles
# once; an existing backup is never overwritten, since the first one is the
# genuine pre-dotfiles state.
link() {
    local src="$SCRIPT_DIR/$1" dst="$2"
    if [[ ! -e "$src" ]]; then
        echo "  ⚠️  missing $src, skipping"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        if [[ -e "$dst.predotfiles" ]]; then
            echo "  ⚠️  $dst exists and $dst.predotfiles already present; not touching"
            return 0
        fi
        echo "  ℹ️  backing up $dst to $dst.predotfiles"
        mv "$dst" "$dst.predotfiles"
    fi
    ln -sfn "$src" "$dst"
    echo "  ✅ $dst"
}

# ---------------------------------------------------------------- packages --
# Names are per package manager because they genuinely differ (timew is
# `timewarrior` on brew). Only what this repo's configs actually invoke is
# listed -- if nothing here shells out to it, it does not belong.

# Portable: the CLI half works the same on every machine.
PKGS_CLI_ARCH=(zsh tmux starship atuin jq fzf eza zoxide neovim git)
PKGS_CLI_BREW=(zsh tmux starship atuin jq fzf eza zoxide neovim git)

# The Linux desktop. Split from optional because without these the neu shell
# either will not start or renders wrong.
#   qt6-5compat    Qt5Compat.GraphicalEffects -> NeuSurface's inset shadows
#   qt6-declarative QtQuick.Effects.RectangularShadow -> the raised pair
#   ttf-ubuntu-mono-nerd  every icon in the bar, dock, spotlight and prompt
#   librsvg/ffmpeg  theme/gen.py rasterises the wallpaper and the cursor
#   libpulse/iw     bin/neu_sysinfo.sh reads volume and wifi through these
PKGS_DESKTOP_ARCH=(
    hyprland hyprpaper hypridle hyprlock hyprcursor
    quickshell qt6-declarative qt6-5compat qt6ct
    ttf-ubuntu-mono-nerd adwaita-fonts breeze-icons
    libpulse iw jq python librsvg ffmpeg libnotify
    waybar wofi dunst          # panic-mode fallback, see NEU_THEME.md
)

# Used by panes and binds, but the shell degrades gracefully without them.
PKGS_OPTIONAL_ARCH=(task timew tea playerctl copyq wtype grim slurp ghostty kitty)

missing_pkgs() {
    local -n _list=$1
    local out=() p
    for p in "${_list[@]}"; do
        case "$PKG_MGR" in
            pacman) pacman -Qq "$p" &>/dev/null && continue ;;
            brew)   brew list --versions "$p" &>/dev/null && continue ;;
        esac
        # A same-named binary already on PATH means the need is met however it
        # got there -- starship and atuin arrive via the bootstrap below, and
        # zoxide/eza are often cargo-installed.
        command -v "$p" >/dev/null 2>&1 && continue
        # Fonts are about the family being resolvable, not where it came from:
        # these are frequently dropped into ~/.local/share/fonts by hand.
        # fc-match, not `fc-list | grep`: grep -q closes the pipe early, fc-list
        # dies on SIGPIPE, and `set -o pipefail` turns that into a false miss.
        # fc-match always answers, so the family has to be compared -- an
        # unresolvable name silently falls back to something else.
        case "$p" in
            ttf-ubuntu-mono-nerd)
                [[ "$(fc-match "UbuntuMono Nerd Font" -f '%{family}' 2>/dev/null)" == *UbuntuMono* ]] \
                    && continue ;;
            adwaita-fonts)
                [[ "$(fc-match "Adwaita Sans" -f '%{family}' 2>/dev/null)" == *Adwaita* ]] \
                    && continue ;;
        esac
        out+=("$p")
    done
    printf '%s\n' "${out[@]:-}"
}

do_packages() {
    PKG_MGR=""
    command -v pacman >/dev/null 2>&1 && PKG_MGR=pacman
    [[ -z "$PKG_MGR" ]] && command -v brew >/dev/null 2>&1 && PKG_MGR=brew
    if [[ -z "$PKG_MGR" ]]; then
        echo "📦 No pacman or brew found; skipping the package check."
        return 0
    fi

    local want=()
    if [[ "$PKG_MGR" == "pacman" ]]; then
        want+=("${PKGS_CLI_ARCH[@]}")
        [[ "$MODE" == "full" ]] && want+=("${PKGS_DESKTOP_ARCH[@]}" "${PKGS_OPTIONAL_ARCH[@]}")
    else
        want+=("${PKGS_CLI_BREW[@]}")
    fi

    local miss
    mapfile -t miss < <(missing_pkgs want)
    # mapfile on empty input still yields one empty element
    [[ ${#miss[@]} -eq 1 && -z "${miss[0]}" ]] && miss=()

    if [[ ${#miss[@]} -eq 0 ]]; then
        echo "📦 All packages present."
        return 0
    fi

    if (( PACKAGES )); then
        echo "📦 Installing ${#miss[@]} missing package(s) with $PKG_MGR..."
        case "$PKG_MGR" in
            # Not --noconfirm: this is the one step that touches the system
            # outside $HOME, so it should be seen before it happens.
            pacman) sudo pacman -S --needed "${miss[@]}" ;;
            brew)   brew install "${miss[@]}" ;;
        esac
    else
        echo "📦 Missing ${#miss[@]} package(s): ${miss[*]}"
        case "$PKG_MGR" in
            pacman) echo "   install with: $0 --packages   (or: sudo pacman -S --needed ${miss[*]})" ;;
            brew)   echo "   install with: $0 --packages   (or: brew install ${miss[*]})" ;;
        esac
    fi
}

do_packages

echo "🔗 Linking CLI configs..."
link zshrc/.zshenv           "$HOME/.zshenv"
link zshrc/.zshrc            "$HOME/.zshrc"
link tmux_conf/.tmux.conf    "$HOME/.tmux.conf"
link starship/starship.toml  "$HOME/.config/starship.toml"
link atuin/config.toml       "$HOME/.config/atuin/config.toml"
link bin/tmux-session-manager.sh "$HOME/.config/tms/tmux-session-manager.sh"

if [[ "$MODE" == "full" ]]; then
    # Desktop utility scripts go on PATH so nothing (hyprland binds, other
    # scripts) needs to know where this repo is cloned.
    echo "🔗 Linking scripts into ~/.local/bin..."
    for f in "$SCRIPT_DIR"/bin/*.sh; do
        link "bin/$(basename "$f")" "$HOME/.local/bin/$(basename "$f")"
    done

    echo "🔗 Linking desktop configs..."
    # hyprland.conf was replaced by hyprland.lua (Hyprland >= 0.55)
    old="$HOME/.config/hypr/hyprland.conf"
    if [[ -L "$old" && "$(readlink -f "$old" 2>/dev/null || true)" == "$SCRIPT_DIR"/* ]]; then
        rm "$old" && echo "  🧹 removed stale $old (replaced by hyprland.lua)"
    fi
    for f in hyprland.lua hypridle.conf hyprlock.conf hyprpaper.conf neu.lua; do
        link "hypr/$f" "$HOME/.config/hypr/$f"
    done
    for f in "$SCRIPT_DIR"/waybar/*; do
        link "waybar/$(basename "$f")" "$HOME/.config/waybar/$(basename "$f")"
    done
    # Quickshell configs are whole directory trees, so link the package itself
    # rather than each file; `qs -c commandcenter` resolves it by that name.
    link quickshell               "$HOME/.config/quickshell/commandcenter"
    link kitty/kitty.conf         "$HOME/.config/kitty/kitty.conf"
    link kitty/neu.conf           "$HOME/.config/kitty/neu.conf"
    link alacritty/alacritty.toml "$HOME/.config/alacritty/alacritty.toml"
    link alacritty/neu.toml       "$HOME/.config/alacritty/neu.toml"
    link wofi/config              "$HOME/.config/wofi/config"
    link wofi/style.css           "$HOME/.config/wofi/style.css"
    link ghostty/config           "$HOME/.config/ghostty/config"
    link ghostty/themes/neu       "$HOME/.config/ghostty/themes/neu"
    link dunst/dunstrc            "$HOME/.config/dunst/dunstrc"
    link tmux_conf/neu.conf       "$HOME/.tmux-neu.conf"

    # --- neu theme: app toolkits -------------------------------------------
    # These were real files before the theme port; link() moves each to
    # <file>.predotfiles once, and uninstall_config.sh puts them back.
    echo "🎨 Linking neu theme (GTK / Qt)..."
    link gtk/settings.ini  "$HOME/.config/gtk-3.0/settings.ini"
    link gtk/gtk.css       "$HOME/.config/gtk-3.0/gtk.css"
    link gtk4/gtk.css      "$HOME/.config/gtk-4.0/gtk.css"
    link qt6ct/qt6ct.conf  "$HOME/.config/qt6ct/qt6ct.conf"
    link qt6ct/neu.conf    "$HOME/.config/qt6ct/colors/neu.conf"

    # Cursor. Two themes, both called `neu`, in separate roots on purpose:
    # they must not share a cursors/ directory or Xcursor would try to parse
    # hyprcursor's .hlc files. Build them with:
    #   python3 theme/cursor/gen_cursor.py
    echo "🖱️  Linking neu cursor..."
    link theme/cursor/build/xcursor/neu "$HOME/.icons/neu"
    link theme/cursor/build/hypr/neu    "$HOME/.local/share/icons/neu"
    for f in "$SCRIPT_DIR"/tms_projects/*.conf; do
        link "tms_projects/$(basename "$f")" "$HOME/.config/tms/projects/$(basename "$f")"
    done
fi

# --- Generated theme files ---------------------------------------------------
# Several generated files embed an absolute path ($HOME in qt6ct.conf, the repo
# root in hyprpaper.conf and hyprlock.conf), so a checkout on a different machine
# -- or in a different directory -- ships stale paths. Regenerating is cheap and
# idempotent, so do it whenever the tree does not already match.
#
# This WRITES to the repo, which matters when testing with a throwaway HOME: the
# sandbox path would be baked in. Pass --no-generate for that (see NEU_THEME.md).

if [[ "$MODE" == "full" && "$GENERATE" == "1" ]] && command -v python3 >/dev/null 2>&1; then
    if [[ -f "$SCRIPT_DIR/theme/gen.py" ]]; then
        if ! python3 "$SCRIPT_DIR/theme/gen.py" --check >/dev/null 2>&1; then
            echo "🎨 Generated theme files are stale for this machine; regenerating..."
            python3 "$SCRIPT_DIR/theme/gen.py" | sed 's/^/  /' || \
                echo "  ⚠️  theme/gen.py failed; the linked configs may carry another machine's paths"
        fi
    fi

    # The cursor is a build artifact; without it the two icon links dangle.
    if [[ ! -d "$SCRIPT_DIR/theme/cursor/build/xcursor/neu" ]]; then
        echo "🖱️  Building the neu cursor..."
        python3 "$SCRIPT_DIR/theme/cursor/gen_cursor.py" | tail -2 | sed 's/^/  /' || \
            echo "  ⚠️  cursor build failed (needs rsvg-convert + ffmpeg)"
    fi
fi

# --- Bootstrap (workspace mode only) -----------------------------------------
# Best-effort: a workspace must still start with no network, so every step
# warns and moves on instead of failing the script. Runs after linking so
# configs land even offline.

bootstrap_starship() {
    if command -v starship >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/starship" ]]; then
        return 0
    fi
    mkdir -p "$HOME/.local/bin"
    if curl -sSfL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"; then
        echo "  ✅ starship installed to ~/.local/bin"
    else
        echo "  ⚠️  starship install failed"
    fi
}

bootstrap_tpm() {
    if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
        return 0
    fi
    if ! command -v git >/dev/null 2>&1; then
        echo "  ⚠️  git missing; skipping TPM"
        return 0
    fi
    if git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"; then
        if command -v tmux >/dev/null 2>&1; then
            "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
        fi
        echo "  ✅ TPM installed"
    else
        echo "  ⚠️  TPM clone failed"
    fi
}

if [[ "$MODE" == "minimal" && "$BOOTSTRAP" == "1" ]]; then
    echo "🛠️  Bootstrapping tools (best-effort)..."
    bootstrap_starship || echo "  ⚠️  starship bootstrap failed"
    bootstrap_tpm      || echo "  ⚠️  TPM bootstrap failed"
fi

echo "✅ Dotfiles installation complete."
