#!/usr/bin/env bash
# ============================================================================
#  setup-linux.sh — Multi-distro Linux orchestrator for linux-win-setup.
#
#  If you run it without arguments it shows an interactive stage menu.
#  Non-interactive alternatives are documented in README.md.
#
#  Usage:
#    sudo ./setup-linux.sh                 (interactive stage picker)
#    sudo ./setup-linux.sh --all           (run every stage in order)
#    sudo ./setup-linux.sh --stages 1,3,5  (run only selected stages)
#    sudo ./setup-linux.sh --resume        (continue where the last run stopped)
#    ./setup-linux.sh --dry-run --all      (preview without changing anything)
#    ./setup-linux.sh --help
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
#  Repository paths (position-independent: works from anywhere).
# ----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC2034
SCRIPT_CONFIGS="$SCRIPT_DIR/configs"
STAGE_LOCATION="$SCRIPT_DIR/stages"

import() { # shellcheck disable=SC1090
    local file="$REPO_ROOT/lib/$1"
    if [[ ! -f "$file" ]]; then
        echo "Missing library: $file" >&2
        exit 1
    fi
    . "$file"
}

import ui.sh
import os.sh
import stages.sh

# ----------------------------------------------------------------------------
#  CLI parsing — turns flags into the same selection logic used by the menu.
# ----------------------------------------------------------------------------
usage() {
    local cmd="${LWS_INVOKE:-setup-linux.sh}"
    cat <<EOF
linux-win-setup — Linux setup (multi-distro)

Usage:
  bash $cmd [options]

Options:
  --all          Run every stage in order (repos, update, packages, apps,
                 terminal, browser, gaming, docker, cleanup)
  --stages 1,3,5 Run only the given stage numbers
  --minimal      Run just the terminal + browser stages
  --revert       Uninstall everything the setup installed/configured
  --resume       Skip stages already completed in a previous run
  --dry-run      Show what would happen, make no changes
  --yes          Assume "yes" for all interactive prompts
  --log FILE     Path to the log file (default ~/.config/linux-win-setup.log)
  --help         Show this help and exit

Examples:
  bash $cmd --all
  bash $cmd --stages 2,5,6
  bash $cmd --revert
  bash $cmd --resume
  bash $cmd --dry-run --all
EOF
}

SELECTION=""
# shellcheck disable=SC2034
while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)     SELECTION="all"; shift ;;
        --revert)  SELECTION="revert"; shift ;;
        --resume)  SELECTION="resume"; shift ;;
        --stages)  SELECTION="${2:-}"; shift 2 ;;
        --minimal) SELECTION="5,6"; shift ;;   # terminal + browser
        --dry-run) DRY_RUN=true; shift ;;
        --yes)     ASSUME_YES=true; shift ;;
        --log)     LOG_FILE="${2:-}"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *)
            case "$1" in
                all|minimal|resume|revert|stages|dry-run|yes|log|help)
                    echo "Unknown option: $1 — did you mean --$1?" >&2
                    ;;
                *) echo "Unknown option: $1" >&2 ;;
            esac
            usage; exit 1
            ;;
    esac
done

[[ "${LWS_BANNER_SHOWN:-0}" == "1" ]] || banner "Linux Setup — multi-distro"

# ----------------------------------------------------------------------------
#  Environment checks before doing anything real.
#  When not root, re-exec the whole run under sudo so every package-manager
#  call runs directly as root (runas_root) instead of prompting for a sudo
#  password inside the spinner, which has no terminal and would hang.
# ----------------------------------------------------------------------------
if [[ "$DRY_RUN" != "true" ]] && [[ $EUID -ne 0 ]]; then
    can_elevate=false
    if command -v sudo >/dev/null 2>&1; then
        if sudo -n true 2>/dev/null; then
            can_elevate=true
        elif [[ -t 0 ]] && sudo -v; then
            # Interactive: cache the sudo credentials on the real terminal so
            # the re-exec and every runas_root call run without prompting.
            can_elevate=true
        fi
    fi
    if [[ "$can_elevate" == "true" ]]; then
        export LWS_BANNER_SHOWN=1
        exec sudo -E bash "$0" "$@"
    fi
    echo -e "${RED}This script needs sudo. Run: sudo bash ${LWS_INVOKE:-setup-linux.sh}${NC}" >&2
    exit 1
fi

distro_id="$(detect_distro)"
family_id="$(detect_family)"
system_alias="$(detect_system)"

echo -e "  ${GREEN}► System: ${BOLD}$system_alias${NC}  Distro: ${BOLD}$distro_id${NC}  Family: ${BOLD}$family_id${NC}"
echo -e "  ${GREEN}► Target user: ${BOLD}$TARGET_USER${NC} ($TARGET_HOME)"
[[ "$DRY_RUN" == "true" ]] && echo -e "  ${YELLOW}[DRY-RUN] No changes will be made${NC}"
echo ""

if [[ "$system_alias" != "linux" && "$system_alias" != "wsl" ]]; then
    echo -e "${RED}This script requires Linux/WSL. On Windows use windows/setup-windows.ps1 or wsl/setup-wsl.sh${NC}" >&2
    exit 1
fi

# ----------------------------------------------------------------------------
#  Source the stage definitions (everything reusable lives in stages/).
# ----------------------------------------------------------------------------
for f in "$STAGE_LOCATION"/stage_*.sh; do
    # shellcheck disable=SC1090
    . "$f"
done

# ---------------------------------------------------------------------------
#  Fall back to the interactive menu when no stage flag was given and the
#  terminal is attached (otherwise default to every stage, CI-friendly).
# ---------------------------------------------------------------------------
if [[ -z "$SELECTION" ]]; then
    if [[ -t 0 ]]; then
        SELECTION="$(show_menu)"
    else
        SELECTION="all"
    fi
fi

plan="$(resolve_selection "$SELECTION")"

run_plan "$plan"