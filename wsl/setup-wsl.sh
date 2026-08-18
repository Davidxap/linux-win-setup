#!/usr/bin/env bash
# ============================================================================
#  wsl/setup-wsl.sh — Lightweight setup for WSL (Windows Subsystem for Linux).
#
#  WSL runs a real Linux (usually Debian/Ubuntu) but without a desktop,
#  systemd services or GPU tuning. This script only installs what helps in
#  WSL: the fish shell, its pleasant config, and a few lightweight CLI tools.
#
#  Usage:
#    bash wsl/setup-wsl.sh                # fish + config + default shell
#    bash wsl/setup-wsl.sh --all          # also installs the CLI tool set
#    bash wsl/setup-wsl.sh --dry-run      # preview without changes
#    bash wsl/setup-wsl.sh --help
# ============================================================================

set -euo pipefail

# Reuse the libraries from the repo (OS detection + package wrappers).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_CONFIGS="$REPO_ROOT/linux/configs"
MANIFESTS="$REPO_ROOT/linux/manifests"

. "$REPO_ROOT/lib/ui.sh"
. "$REPO_ROOT/lib/os.sh"
. "$REPO_ROOT/lib/stages.sh"

DRY_RUN="${DRY_RUN:-false}"
ASSUME_YES="${ASSUME_YES:-false}"

usage() {
    local cmd="${LWS_INVOKE:-wsl/setup-wsl.sh}"
    cat <<EOF
linux-win-setup — WSL setup

Usage:
  bash $cmd [options]

Options:
  --all        Also install the extra CLI tool set (eza, bat, fzf, ...)
  --dry-run    Show what would happen, make no changes
  --help       Show this help
EOF
}

# ----------------------------------------------------------------------------
#  Deploy the repo's fish configuration to the target user's home.
# ----------------------------------------------------------------------------
deploy_fish_config() {
    local cfg="$SCRIPT_CONFIGS/fish"
    copy_config "$cfg/config.fish"            "$TARGET_HOME/.config/fish/config.fish"
    copy_config "$cfg/conf.d/colors.fish"    "$TARGET_HOME/.config/fish/conf.d/colors.fish"
    copy_config "$cfg/conf.d/rustup.fish"    "$TARGET_HOME/.config/fish/conf.d/rustup.fish"
    copy_config "$cfg/conf.d/uv.env.fish"    "$TARGET_HOME/.config/fish/conf.d/uv.env.fish"
}

# ----------------------------------------------------------------------------
#  Make fish the default shell for the target user.
# ----------------------------------------------------------------------------
set_default_shell() {
    local shell_path
    shell_path="$(command -v fish 2>/dev/null || true)"
    if [[ -z "$shell_path" ]]; then
        warn "fish not found — skipping default shell change"
        return 1
    fi
    if [[ "$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f7)" == "$shell_path" ]]; then
        skip "fish is already the default shell"
        return 0
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} chsh -s $shell_path $TARGET_USER"
        return 0
    fi
    root_run chsh -s "$shell_path" "$TARGET_USER"
    info "Restart WSL (wsl --shutdown) for the change to apply."
}

# ----------------------------------------------------------------------------
#  Main.
# ----------------------------------------------------------------------------
main() {
    [[ "${LWS_BANNER_SHOWN:-0}" == "1" ]] || banner "Setup for WSL — fish shell + CLI tools"

    DRY_RUN=$( [[ "$*" == *--dry-run* ]] && echo true || echo false )
    local extra=false
    case "$*" in
        *--help*) usage; return 0 ;;
        *--all*)  extra=true ;;
    esac

    # Helper: only install fish (the manifest is read below when needed).
    info "Installing fish and its configuration"
    pkg_install fish
    deploy_fish_config
    set_default_shell

    if [[ "$extra" == "true" ]]; then
        local manifest="$MANIFESTS/wsl-debian.txt"
        info "Installing extra CLI tools from manifests/wsl-debian.txt"
        local missing=()
        local pkg
        while read -r pkg; do
            [[ -z "$pkg" ]] && continue
            pkg_installed "$pkg" || missing+=("$pkg")
        done < <(read_manifest "$manifest")
        if (( ${#missing[@]} > 0 )); then
            pkg_install "${missing[@]}"
        else
            ok "All CLI tools are already installed"
        fi
    fi

    echo ""
    echo "  Done. Restart WSL (wsl --shutdown) and fish will be your shell."
}

main "$@"