# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export PROMPT='%m:%~ %n %# '
export PATH=~/.local/bin:$PATH
export BROWSER=librewolf

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="agnoster"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh
bindkey -v
bindkey '^R' history-incremental-search-backward

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias inv='nvim $(fzf --preview="bat --color=always {}")'
alias nv=nvim
alias n='nvim .'
alias nb='newsboat -r'
load_tmux() {
  if [[ -n "$TMUX" ]]; then
    # Already inside tmux — switch, don't nest
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
    # Outside tmux — existing behavior
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
alias t=load_tmux
alias tn=tmux
alias tks='tmux kill-server'
alias tns='tmux new -s'
alias ta='tmux a'
alias tat='tmux a -t'
alias oc=opencode
alias rp=repoman

if [ -d "$HOME/.rgtv" ]; then
    source "$HOME/.rgtv/.rgtv.sh"
fi

# Load hof script
if [[ -f "$HOME/.hof.sh" ]]; then
    source "$HOME/.hof.sh"
fi

_motd() {
  local sapphire='\033[38;2;116;199;236m'
  local text='\033[38;2;205;214;244m'
  local peach='\033[38;2;250;179;135m'
  local overlay0='\033[38;2;108;112;134m'
  local reset='\033[0m'

  # Line 1: date
  local date_str
  date_str=$(date +"%a %b %d")
  printf '%b\n' "${sapphire}  ${date_str}${reset}"

  # Line 2: tmux sessions (only if any active)
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

  # Line 2: tasks due today
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

    # Line 3: overdue warning
    local overdue_count
    overdue_count=$(task +OVERDUE status:pending count 2>/dev/null)
    if [[ -n "$overdue_count" ]] && (( overdue_count > 0 )); then
      printf '%b\n' " ${peach} ${overdue_count} overdue${reset}"
    fi
  fi
}
_motd

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

# opencode
export PATH=/home/jwbla/.opencode/bin:$PATH
