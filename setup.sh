#!/usr/bin/env bash
# ============================================================================
#  setup.sh — Entry point for linux-win-setup.
#  Detects the host (Linux / WSL / Windows 11) and delegates to the matching
#  setup script, so the user only ever needs to remember one command.
#
#  Usage:
#    ./setup.sh                 (detect and run the right setup)
#    ./setup.sh --dry-run       (preview without making changes)
#    ./setup.sh --help          (help for the detected platform)
# ============================================================================

set -euo pipefail

BOLD=$'\033[1m'
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

print_banner() {
    local grad=( "38;2;245;194;231" "38;2;203;166;247" "38;2;137;180;250" \
                 "38;2;137;220;235" "38;2;148;226;213" "38;2;166;227;161" )
    local art
    art="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/banner.art"
    local b="" c="" r=""
    if [[ -t 1 ]]; then
        b=$'\033[1m'; r=$'\033[0m'
    fi
    local i=0 line
    while IFS= read -r line; do
        [ -n "$line" ] || { i=$((i + 1)); continue; }
        if [[ -t 1 ]]; then
            c=$'\033['"${grad[$((i % ${#grad[@]}))]}"'m'
        fi
        printf '    %s%s%s\n' "$b$c" "$line" "$r"
        i=$((i + 1))
    done <"$art"
    echo ""
    echo -e "  ${BOLD}linux-win-setup${NC} — automated setup"
    echo -e "  ${YELLOW}https://github.com/Davidxap/linux-win-setup${NC}"
    echo ""
}

detect_system() {
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [[ "$(uname -s 2>/dev/null)" == "Linux" ]]; then
        echo "linux"
    elif command -v cmd.exe &>/dev/null || [[ -n "${WINDIR:-}" || -n "${OS:-}" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# ----------------------------------------------------------------------------
#  hint_update — warn when this copy of linux-win-setup is an old git checkout
#  (the public repo keeps a single root commit, so `git pull` can fail with
#  "divergent branches"). Points the user at the safe reset command.
# ----------------------------------------------------------------------------
hint_update() {
    local dir git_ok remote_head
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    git_ok="$(command -v git 2>/dev/null || true)"
    [[ -n "$git_ok" ]] || return 0
    [[ -d "$dir/.git" ]] || return 0

    remote_head="$(git -C "$dir" ls-remote origin HEAD 2>/dev/null | awk '{print $1}' || true)"
    if [[ -z "$remote_head" ]]; then
        return 0
    fi
    if [[ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" != "$remote_head" ]]; then
        echo -e "  ${YELLOW}⚠ This copy is outdated (public repo is a single-commit tree).${NC}"
        echo -e "  ${YELLOW}  Update it with:  git fetch origin && git reset --hard origin/main${NC}"
        echo ""
    fi
}

main() {
    print_banner
    hint_update
    local system run
    system="$(detect_system)"
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    case "$system" in
        linux)
            echo -e "${GREEN}► Detected: Linux${NC}"
            run="$script_dir/linux/setup-linux.sh"
            ;;
        wsl)
            echo -e "${GREEN}► Detected: WSL (Linux-on-Windows)${NC}"
            run="$script_dir/wsl/setup-wsl.sh"
            ;;
        windows)
            echo -e "${GREEN}► Detected: Windows 11${NC}"
            run="$script_dir/windows/setup-windows.ps1"
            echo -e "  Run PowerShell first, then:"
            echo -e "  ${CYAN}powershell -ExecutionPolicy Bypass -File windows\\setup-windows.ps1${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}► Unknown/unsupported system. Use Linux, WSL or Windows 11.${NC}" >&2
            exit 1
            ;;
    esac

    if [[ ! -f "$run" ]]; then
        echo -e "${RED}✗ Setup script missing: $run${NC}" >&2
        exit 1
    fi

    export LWS_INVOKE
    LWS_INVOKE="$(basename "$0")"
    export LWS_BANNER_SHOWN=1
    bash "$run" "$@"
}

main "$@"