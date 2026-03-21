# ------------------------------
# Environment & Exports
# ------------------------------
export ZSH="$HOME/.oh-my-zsh"
export PROMPT='%m:%~ %n %# '
export PATH=~/.local/bin:~/.cargo/bin:/home/jwbla/.opencode/bin:$PATH
export BROWSER=librewolf

# ------------------------------
# Oh-My-Zsh
# ------------------------------
zstyle ':omz:update' mode auto
plugins=(git)
source $ZSH/oh-my-zsh.sh

# ------------------------------
# Key Bindings
# ------------------------------
bindkey -v
bindkey '^R' history-incremental-search-backward

# ------------------------------
# Aliases: Editor
# ------------------------------
alias inv='nvim $(fzf --preview="bat --color=always {}")'
alias nv=nvim
alias n='nvim .'

# ------------------------------
# Aliases: Tmux
# ------------------------------
alias t=load_tmux
alias tls='tmux list-sessions'
alias tm=tmux
alias tks='tmux kill-server'
alias tns='tmux new -s'
alias ta='tmux a'
alias tat='tmux a -t'

# ------------------------------
# Aliases: Git
# ------------------------------
alias gbf='git branch | fzf | sed "s/^[* ]*//" | xargs git checkout'

# ------------------------------
# Aliases: File Listing
# ------------------------------
alias l="eza -l --icons --git -a"
alias lt="eza --tree --level=2 --long --icons --git"
alias ltree="eza --tree --level=2  --icons --git"

# ------------------------------
# Aliases: Misc
# ------------------------------
alias nb='newsboat -r'
alias oc=opencode

# ------------------------------
# Functions
# ------------------------------
load_tmux() {
  if [[ -n "$TMUX" ]]; then
    local sessions="$(tmux list-sessions -F '#{session_name}: #{session_windows} windows (#{session_attached} attached)')"
    local choice="$(printf "+ New Session\n%s" "$sessions" | fzf --prompt="tmux> " --height=~50%)"
    [[ -z "$choice" ]] && return
    if [[ "$choice" == "+ New Session" ]]; then
      tmux new-session -d
      tmux switch-client -t "$(tmux list-sessions -F '#{session_name}' | tail -1)"
    else
      tmux switch-client -t "${choice%%:*}"
    fi
  else
    if ! tmux list-sessions &>/dev/null; then
      tmux
    else
      local sessions="$(tmux list-sessions -F '#{session_name}: #{session_windows} windows (#{session_attached} attached)')"
      local choice="$(printf "+ New Session\n%s" "$sessions" | fzf --prompt="tmux> " --height=~50%)"
      [[ -z "$choice" ]] && return
      if [[ "$choice" == "+ New Session" ]]; then
        tmux
      else
        tmux attach -t "${choice%%:*}"
      fi
    fi
  fi
}

pomo() {
  ~/.config/waybar/pomodoro.sh "$@"
  pkill -RTMIN+8 waybar
}

_motd() {
  local sapphire='\033[38;2;116;199;236m'
  local text='\033[38;2;205;214;244m'
  local peach='\033[38;2;250;179;135m'
  local overlay0='\033[38;2;108;112;134m'
  local reset='\033[0m'

  local date_str
  date_str=$(date +"%a %b %d")
  printf '%b\n' "${sapphire}  ${date_str}${reset}"

  if command -v tmux &>/dev/null; then
    local tmux_names
    tmux_names=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)
    if [[ -n "$tmux_names" ]]; then
      local tmux_joined=""
      local tmux_first=1
      while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        if (( tmux_first )); then
          tmux_first=0
        else
          tmux_joined+="${overlay0}, ${reset}"
        fi
        tmux_joined+="${text}${name}${reset}"
      done <<< "$tmux_names"
      printf '%b\n' " ${sapphire}tmux sessions:${reset} ${tmux_joined}"
    fi
  fi

  if command -v task &>/dev/null; then
    local tasks_today
    tasks_today=$(task rc.verbose=nothing \
      rc.report._motd.columns=id,description.truncated,due.relative \
      rc.report._motd.labels=,,  \
      rc.report._motd.sort=due+ \
      rc.report._motd.filter='due.before:+24h status:pending' \
      rc.defaultwidth=60 \
      _motd 2>/dev/null)
    if [[ -n "$tasks_today" ]]; then
      printf '%b\n' " ${sapphire}󰄲 due within 24h${reset}"
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        printf '%b\n' "   ${text}${line}${reset}"
      done <<< "$tasks_today"
    fi

    local overdue_count
    overdue_count=$(task +OVERDUE status:pending count 2>/dev/null)
    if [[ -n "$overdue_count" ]] && (( overdue_count > 0 )); then
      printf '%b\n' " ${peach} ${overdue_count} overdue${reset}"
    fi
  fi
}

# ------------------------------
# External Sources
# ------------------------------
if [ -d "$HOME/.rgtv" ]; then
    source "$HOME/.rgtv/.rgtv.sh"
fi

# ------------------------------
# Shell Init & MOTD
# ------------------------------
_motd
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
