#!/usr/bin/env bash
# Tmux Session Manager
# Source this file in .zshrc to get tmux-session-manager and tmux-session-manager-tv functions

TMS_CONFIG_DIR="${HOME}/.config/tms/projects"
TMS_PREVIEW_SCRIPT="${HOME}/.config/tms/preview.sh"

_tms_list_projects() {
  local running_sessions
  running_sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)

  for conf in "$TMS_CONFIG_DIR"/*.conf; do
    [[ -f "$conf" ]] || continue
    local name=""
    while IFS='=' read -r key val; do
      [[ "$key" == "name" ]] && name="$val"
    done < "$conf"
    [[ -z "$name" ]] && continue

    if echo "$running_sessions" | grep -qx "$name"; then
      echo "● $name"
    else
      echo "○ $name"
    fi
  done | sort -t' ' -k1,1r
}

_tms_create_session() {
  local name="$1"
  local conf="$TMS_CONFIG_DIR/${name}.conf"
  [[ -f "$conf" ]] || return 1

  local first=1
  while IFS='=' read -r key val; do
    [[ "$key" != "window" ]] && continue

    local wname wdir wcmd
    IFS='|' read -r wname wdir wcmd <<< "$val"
    wdir="${wdir/#\~/$HOME}"

    if (( first )); then
      tmux new-session -d -s "$name" -n "$wname" -c "$wdir"
      first=0
    else
      tmux new-window -t "$name" -n "$wname" -c "$wdir"
    fi

    if [[ -n "$wcmd" ]]; then
      tmux send-keys -t "$name:$wname" "$wcmd" Enter
    fi
  done < "$conf"

  tmux select-window -t "$name:1"
}

_tms_attach() {
  local name="$1"

  if ! tmux has-session -t "$name" 2>/dev/null; then
    _tms_create_session "$name" || return 1
  fi

  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$name"
  else
    tmux attach-session -t "$name"
  fi
}

_tms_ensure_preview_script() {
  mkdir -p "$(dirname "$TMS_PREVIEW_SCRIPT")"
  cat > "$TMS_PREVIEW_SCRIPT" << 'EOF'
#!/usr/bin/env bash
TMS_CONFIG_DIR="${HOME}/.config/tms/projects"
entry="$*"
status="${entry%% *}"
name="${entry#* }"

if [[ "$status" == "●" ]]; then
  echo "SESSION: $name (running)"
  echo "─────────────────────────"
  tmux list-windows -t "$name" -F '  #{window_index}: #{window_name} (#{pane_current_path})' 2>/dev/null
else
  conf="$TMS_CONFIG_DIR/${name}.conf"
  if [[ -f "$conf" ]]; then
    echo "SESSION: $name (not running)"
    echo "─────────────────────────"
    while IFS='=' read -r key val; do
      case "$key" in
        root) echo "  root: $val" ;;
        window)
          IFS='|' read -r wname wdir wcmd <<< "$val"
          if [[ -n "$wcmd" ]]; then
            echo "  ${wname}: ${wcmd} (in ${wdir})"
          else
            echo "  ${wname}: shell (in ${wdir})"
          fi
          ;;
      esac
    done < "$conf"
  fi
fi
EOF
  chmod +x "$TMS_PREVIEW_SCRIPT"
}

tmux-session-manager() {
  _tms_ensure_preview_script

  local choice
  choice=$(_tms_list_projects | fzf \
    --ansi \
    --prompt="tmux project> " \
    --height=~50% \
    --preview="$TMS_PREVIEW_SCRIPT {}" \
    --preview-window=right:50%)

  [[ -z "$choice" ]] && return
  _tms_attach "${choice#* }"
}

tmux-session-manager-tv() {
  _tms_ensure_preview_script

  local list
  list=$(_tms_list_projects)
  [[ -z "$list" ]] && echo "No projects configured." && return

  local choice
  choice=$(echo "$list" | tv \
    --preview-command "$TMS_PREVIEW_SCRIPT {}" \
    --ansi \
    --no-sort)

  [[ -z "$choice" ]] && return
  _tms_attach "${choice#* }"
}
