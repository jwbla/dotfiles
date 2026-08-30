#!/usr/bin/env bash
# Emit the XDG application list as JSON for the neu Spotlight launcher.
#
# Quickshell's own DesktopEntries model comes back empty on this machine, so the
# launcher reads $XDG_DATA_DIRS itself. ~94 files parse in a few milliseconds.
#
# [{"name","exec","icon","comment","id"}]  -- NoDisplay/Hidden entries dropped,
# Exec field codes (%U %f %i ...) stripped, terminal apps prefixed.
set -uo pipefail

dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:${XDG_DATA_HOME:-$HOME/.local/share}"

# -print0/xargs, so awk receives the files as ARGUMENTS (FNR/FILENAME per file)
# rather than a list of names on stdin.
find ${dirs//:/ } -maxdepth 2 -name '*.desktop' -type f 2>/dev/null | sort -u |
xargs -d '\n' -r awk '
function esc(s) {
    gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
    gsub(/\t/, " ", s);    gsub(/\r/, "", s)
    return s
}
function flush() {
    if (name != "" && exec != "" && nodisplay != "true" && hidden != "true") {
        gsub(/ ?%[UufFickdDnNvm]/, "", exec)
        sub(/[[:space:]]+$/, "", exec)
        if (n++ > 0) printf ",\n"
        printf "  {\"id\":\"%s\",\"name\":\"%s\",\"exec\":\"%s\",\"icon\":\"%s\",\"comment\":\"%s\",\"terminal\":%s}",
               esc(id), esc(name), esc(exec), esc(icon), esc(comment),
               (terminal == "true" ? "true" : "false")
    }
    name=""; exec=""; icon=""; comment=""; nodisplay=""; hidden=""; terminal=""; insection=0
}
BEGIN { print "["; n=0 }
FNR==1 {
    flush()
    id = FILENAME
    sub(/.*\//, "", id); sub(/\.desktop$/, "", id)
}
/^\[/ { insection = ($0 == "[Desktop Entry]") ? 1 : 0; next }
insection && /^Name=/      && name == ""    { name    = substr($0, 6); next }
insection && /^Exec=/      && exec == ""    { exec    = substr($0, 6); next }
insection && /^Icon=/      && icon == ""    { icon    = substr($0, 6); next }
insection && /^Comment=/   && comment == "" { comment = substr($0, 9); next }
insection && /^NoDisplay=/  { nodisplay = substr($0, 11); next }
insection && /^Hidden=/     { hidden    = substr($0, 8);  next }
insection && /^Terminal=/   { terminal  = substr($0, 10); next }
END { flush(); print "\n]" }
'
