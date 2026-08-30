#!/usr/bin/env bash
# Back out of the neu (@rgtv/neu) desktop theme. See NEU_THEME.md.
#
#   neu-revert.sh --snapshot   record pre-install state (run this BEFORE installing)
#   neu-revert.sh --status     show what is currently linked into the repo
#   neu-revert.sh --soft       stash the theme work, reinstall committed configs
#   neu-revert.sh              full revert: discard the theme work entirely
#   neu-revert.sh -y           ... without the confirmation prompt
#
# The full revert runs `git clean -fd` inside the dotfiles repo, which would
# delete this script while it is executing. So it re-execs itself from a copy in
# /tmp first; that is what the NEU_REVERT_DETACHED guard below is for.
set -uo pipefail

REPO_DEFAULT="$HOME/dev/dotfiles"
REPO="${NEU_REPO:-$REPO_DEFAULT}"
SNAP="${XDG_CACHE_HOME:-$HOME/.cache}/neu-theme"
GS=org.gnome.desktop.interface
GS_KEYS=(gtk-theme icon-theme cursor-theme font-name color-scheme monospace-font-name)

MODE=full
ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --snapshot) MODE=snapshot ;;
        --status)   MODE=status ;;
        --soft)     MODE=soft ;;
        -y|--yes)   ASSUME_YES=1 ;;
        -h|--help)  sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "usage: $0 [--snapshot|--status|--soft] [-y]" >&2; exit 2 ;;
    esac
done

die() { echo "neu-revert: $*" >&2; exit 1; }
say() { echo "  $*"; }

[[ -d "$REPO/.git" ]] || die "no dotfiles repo at $REPO (set NEU_REPO)"

# --- snapshot ---------------------------------------------------------------

do_snapshot() {
    mkdir -p "$SNAP"
    echo "Recording pre-install state to $SNAP"

    if command -v gsettings >/dev/null 2>&1; then
        : >"$SNAP/gsettings"
        for k in "${GS_KEYS[@]}"; do
            v="$(gsettings get "$GS" "$k" 2>/dev/null)" || continue
            printf '%s\t%s\n' "$k" "$v" >>"$SNAP/gsettings"
        done
        say "gsettings: $(wc -l <"$SNAP/gsettings") keys"
    fi

    # Which targets are real files right now. install.sh backs each of these up
    # to <file>.predotfiles the first time it links over one; this record is how
    # we tell "there was never a file here" from "the backup went missing".
    : >"$SNAP/pre-existing"
    while IFS= read -r f; do
        [[ -e "$f" && ! -L "$f" ]] && printf 'file\t%s\n' "$f" >>"$SNAP/pre-existing"
        [[ -L "$f" ]] && printf 'link\t%s\t%s\n' "$f" "$(readlink -f "$f")" >>"$SNAP/pre-existing"
    done <<EOF
$HOME/.config/gtk-3.0/settings.ini
$HOME/.config/gtk-3.0/gtk.css
$HOME/.config/gtk-4.0/gtk.css
$HOME/.config/qt6ct/qt6ct.conf
$HOME/.config/qt5ct/qt5ct.conf
$HOME/.config/hypr/hyprland.lua
$HOME/.config/hypr/hyprlock.conf
$HOME/.config/hypr/hyprpaper.conf
$HOME/.config/starship.toml
$HOME/.tmux.conf
$HOME/.zshrc
EOF
    say "pre-existing: $(wc -l <"$SNAP/pre-existing") paths"

    git -C "$REPO" rev-parse HEAD >"$SNAP/head" 2>/dev/null
    say "repo HEAD: $(cat "$SNAP/head" 2>/dev/null | cut -c1-8)"
    echo "Snapshot done. Full revert: $0"
}

# --- status -----------------------------------------------------------------

do_status() {
    echo "Repo:     $REPO"
    echo "Snapshot: $([[ -d $SNAP ]] && echo "$SNAP" || echo 'NONE — run --snapshot first')"
    echo
    echo "Uncommitted theme work:"
    git -C "$REPO" status --short | sed 's/^/  /' || true
    echo
    echo "Symlinks pointing into the repo:"
    find "$HOME/.config" "$HOME/.local/bin" "$HOME" -maxdepth 2 -type l 2>/dev/null |
        while IFS= read -r l; do
            t="$(readlink -f "$l" 2>/dev/null)"
            [[ "$t" == "$REPO"/* ]] && echo "  $l"
        done
    echo
    echo "Dangling symlinks (should be none):"
    find "$HOME/.config" "$HOME/.local/bin" -maxdepth 3 -xtype l 2>/dev/null | sed 's/^/  /'
    echo
    echo "Shell:    $(pgrep -f '^qs .*-c commandcenter' >/dev/null && echo 'neu (quickshell)' || echo 'not running')"
    echo "waybar:   $(pgrep -x waybar >/dev/null && echo running || echo stopped)"
}

# --- revert -----------------------------------------------------------------

restore_gsettings() {
    [[ -f "$SNAP/gsettings" ]] || { say "no gsettings snapshot; skipping"; return; }
    command -v gsettings >/dev/null 2>&1 || return
    while IFS=$'\t' read -r k v; do
        [[ -n "$k" ]] && gsettings set "$GS" "$k" "$v" 2>/dev/null &&
            say "gsettings $k -> $v"
    done <"$SNAP/gsettings"
}

do_revert() {
    if (( ! ASSUME_YES )); then
        echo "This will:"
        echo "  1. stop the neu shell and restore waybar"
        echo "  2. remove every symlink pointing into $REPO and restore .predotfiles backups"
        echo "  3. restore gsettings from $SNAP"
        if [[ "$MODE" == soft ]]; then
            echo "  4. STASH the uncommitted theme work (recoverable with 'git stash pop')"
        else
            echo "  4. DISCARD all uncommitted work in $REPO — permanently"
        fi
        echo "  5. re-run install.sh to relink the committed configs"
        echo
        read -rp "Proceed? (y/N): " c
        [[ "$c" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
    fi

    echo "1/5 stopping the neu shell"
    pkill -f '^qs .*-c commandcenter' 2>/dev/null && say "quickshell stopped"
    pkill -x waybar 2>/dev/null
    (waybar >/dev/null 2>&1 &) ; say "waybar started"

    echo "2/5 removing repo symlinks"
    "$REPO/uninstall_config.sh" -y | sed 's/^/  /'

    echo "3/5 restoring gsettings"
    restore_gsettings

    echo "4/5 restoring the repo to its committed state"
    if [[ "$MODE" == soft ]]; then
        git -C "$REPO" stash push -u -m "neu theme (reverted $(date -Iseconds))" |
            sed 's/^/  /'
        say "recover with: git -C $REPO stash pop"
    else
        git -C "$REPO" checkout -- . 2>/dev/null
        git -C "$REPO" clean -fd | sed 's/^/  /'
    fi

    echo "5/5 relinking committed configs"
    "$REPO/install.sh" --full --no-bootstrap | sed 's/^/  /'

    echo
    echo "Done. Reboot to get the pre-theme session back:"
    echo "    systemctl reboot"
    echo "Verify no links dangle:"
    echo "    find ~/.config ~/.local/bin -maxdepth 3 -xtype l"
}

case "$MODE" in
    snapshot) do_snapshot ;;
    status)   do_status ;;
    soft|full)
        # Re-exec from outside the repo so `git clean -fd` cannot delete the
        # script out from under bash mid-read.
        if [[ -z "${NEU_REVERT_DETACHED:-}" && "$(readlink -f "$0")" == "$REPO"/* ]]; then
            tmp="$(mktemp /tmp/neu-revert.XXXXXX.sh)"
            cp "$(readlink -f "$0")" "$tmp" && chmod +x "$tmp" || die "could not stage $tmp"
            reargs=()
            [[ "$MODE" == soft ]] && reargs+=(--soft)
            (( ASSUME_YES )) && reargs+=(-y)
            NEU_REVERT_DETACHED=1 exec "$tmp" "${reargs[@]}"
        fi
        do_revert
        ;;
esac
