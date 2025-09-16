#!/usr/bin/env bash
# ~/.hof.sh

# hof: Hall of Fame command launcher
# Uses fzf to search and execute commands from a curated markdown file
hof() {
    local COMMANDS_FILE="$HOME/obsidian/jwbla/linux/shell_cmds_halloffame.md"

    # Check if commands file exists
    if [[ ! -f "$COMMANDS_FILE" ]]; then
        echo "Error: Commands file not found at $COMMANDS_FILE" >&2
        return 1
    fi

    # Extract commands from markdown file
    # Look for code blocks (```sh ... ```) that follow ### headers
    local commands
    commands=$(awk '
    /^###/ { 
        in_section = 1
        next
    }
    /^```sh$/ && in_section { 
        in_code = 1
        next
    }
    /^```$/ && in_code {
        in_code = 0
        in_section = 0
        next
    }
    in_code { 
        print $0
    }' "$COMMANDS_FILE")

    # Check if any commands were found
    if [[ -z "$commands" ]]; then
        echo "No commands found in $COMMANDS_FILE" >&2
        return 1
    fi

    # Use fzf to select command
    local selected_command
    selected_command=$(echo "$commands" | fzf \
        --border \
        --preview-window=right:50% \
        --preview="batcat --style=numbers --color=always --language=markdown '$COMMANDS_FILE'" \
        --bind 'ctrl-/:toggle-preview' \
        --prompt="Select command: ")

    # Exit if no command selected (user pressed Esc or Ctrl+C)
    if [[ -z "$selected_command" ]]; then
        return 0
    fi

    # Execute the selected command
    eval "$selected_command"
}
