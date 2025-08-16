#!/usr/bin/env bash
# ~/.kz.sh

# kz: run repo tasks from utils/ then return to original dir
kz() {
    local orig_dir
    orig_dir=$(pwd)

    # Find git repo root
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -z "$root" ]]; then
        echo "Not inside a git repository."
        return 1
    fi

    # Check utils/ directory
    if [[ ! -d "$root/utils" ]]; then
        echo "utils/ directory not found in repo root."
        return 1
    fi

    cd "$root/utils" || return 1

    # Dispatch based on first argument
    case "$1" in
        build|"")
            uv run build.py
            ;;
        lint)
            uv run tasks/lint_fix.py
            ;;
        build:android)
            uv run tasks/build-android.py
            ;;
        *)
            echo "Unknown command: $1"
            echo "Usage: kz [build|lint|build:android]"
            cd "$orig_dir"
            return 1
            ;;
    esac

    # Return to original directory
    cd "$orig_dir" || return 1
}

