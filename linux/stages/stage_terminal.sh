#!/usr/bin/env bash
# ============================================================================
#  stage: terminal — Install & configure kitty + fish (or just fish).
#
#  Why this setup? Before installing anything the script explains the benefit
#  so newcomers can make an informed choice instead of getting a terminal
#  they did not ask for.
#
#  kitty  : GPU-accelerated, tabs/powerline, copy-on-select, right-click paste
#  fish   : auto-suggestions, real-time syntax colors (green=installed,
#           red=missing), and 'modern' aliases (ls=eza, cat=bat, z=zoxide).
#
#  Options:
#    [1] kitty + fish (full desktop setup, the author's daily driver)
#    [2] fish only     (recommended for WSL / Debian / laptop use)
#    [3] zsh + starship + tmux (modern prompt + multiplexer)
#    [4] skip          (leave the terminal untouched)
#
#  The full keybinding guide lives in README.md → "Terminal guide".
# ============================================================================

stage_terminal() {
    section "Terminal" "kitty + fish — with an explanation, and a choice."

    echo -e "  ${BOLD}Why kitty + fish?${NC}"
    echo -e "   ${CYAN}kitty${NC}: GPU-accelerated rendering (smooth scrolling even with"
    echo -e "          large scrollback), tabs with powerline style, and mouse UX:"
    echo -e "          select = copy, right-click = paste, ctrl+click = open link."
    echo -e "   ${CYAN}fish ${NC}: suggestions in grey as you type (→ accepts them),"
    echo -e "          syntax highlighting that turns the command ${GREEN}green${NC} if it exists"
    echo -e "          or ${RED}red${NC} if it does not, and handy aliases:"
    echo -e "          'ls'=eza(with icons), 'cat'=bat, 'z'=smart cd via zoxide,"
    echo -e "          Ctrl+R / Ctrl+T fuzzy search via fzf."
    echo -e "   ${DIM}Full shortcut reference → README.md (Terminal guide).${NC}"
    echo ""

    local choice
    choice="$(prompt_choice "How do you want the terminal set up?" \
        "kitty + fish (full setup, recommended)" \
        "fish only (for WSL/Debian or existing terminal apps)" \
        "zsh + starship + tmux (modern CLIs + prompt + multiplexer)" \
        "Skip terminal setup")"

    case "$choice" in
        all)
            terminal_full
            ;;
        none)
            info "Terminal setup skipped."
            ;;
        *)
            local n
            for n in $choice; do
                case "$n" in
                    1) terminal_full ;;
                    2) terminal_fish_only ;;
                    3) terminal_zsh ;;
                    4) info "Terminal setup skipped." ;;
                esac
            done
            ;;
    esac
}

# ----------------------------------------------------------------------------
#  terminal_full — install kitty + fish and deploy the repo dotfiles.
# ----------------------------------------------------------------------------
terminal_full() {
    info "Installing kitty + fish"
    pkg_install fish kitty
    record_installed fish kitty

    deploy_fish_config
    deploy_kitty_config
    deploy_ranger_config
    set_default_shell fish
}

# ----------------------------------------------------------------------------
#  terminal_fish_only — fish only (ideal for WSL / Debian minimal).
# ----------------------------------------------------------------------------
terminal_fish_only() {
    info "Installing fish (terminal stays as your system provides)"
    pkg_install fish
    record_installed fish

    deploy_fish_config
    set_default_shell fish
}

# ----------------------------------------------------------------------------
#  terminal_zsh — zsh + starship + tmux + the modern CLIs (the setup shared
#  by @matip_dev: "zsh + starship + tmux with modern CLIs"). The modern
#  CLIs (eza/bat/fd/fzf/zoxide/rg) are already installed by stage "packages";
#  here we add the shell stack and deploy its dotfiles.
# ----------------------------------------------------------------------------
terminal_zsh() {
    info "Installing zsh + starship + tmux (kitty for the emulator)"
    local pkgs=(kitty zsh starship tmux zsh-syntax-highlighting zsh-autosuggestions)
    pkg_install "${pkgs[@]}"
    record_installed "${pkgs[@]}"

    deploy_zsh_config
    set_default_shell zsh
}

# ----------------------------------------------------------------------------
#  deploy_zsh_config — copy the zsh / starship / tmux dotfiles to the target
#  home (mirrors deploy_fish_config / deploy_kitty_config).
# ----------------------------------------------------------------------------
deploy_zsh_config() {
    info "Deploying zsh configuration (starship, tmux, aliases, zoxide, fzf)"
    local base="$SCRIPT_CONFIGS/zsh"

    copy_config "$base/zshrc"        "$TARGET_HOME/.zshrc"
    copy_config "$base/starship.toml" "$TARGET_HOME/.config/starship.toml"
    copy_config "$base/tmux.conf"    "$TARGET_HOME/.tmux.conf"
}

# ----------------------------------------------------------------------------
#  deploy_fish_config — copy the fish dotfiles to the target home.
# ----------------------------------------------------------------------------
deploy_fish_config() {
    info "Deploying fish configuration (autosuggestions, colors, aliases)"
    local base="$SCRIPT_CONFIGS/fish"

    copy_config "$base/config.fish"                 "$TARGET_HOME/.config/fish/config.fish"
    copy_config "$base/conf.d/colors.fish"          "$TARGET_HOME/.config/fish/conf.d/colors.fish"
    copy_config "$base/conf.d/rustup.fish"          "$TARGET_HOME/.config/fish/conf.d/rustup.fish"
    copy_config "$base/conf.d/uv.env.fish"          "$TARGET_HOME/.config/fish/conf.d/uv.env.fish"
    copy_config "$base/completions/copilot.fish"    "$TARGET_HOME/.config/fish/completions/copilot.fish"
}

# ----------------------------------------------------------------------------
#  deploy_kitty_config — copy the kitty dotfiles (theme + shortcuts).
# ----------------------------------------------------------------------------
deploy_kitty_config() {
    info "Deploying kitty configuration (Catppuccin Mocha + shortcuts)"
    local base="$SCRIPT_CONFIGS/kitty"

    copy_config "$base/kitty.conf"                 "$TARGET_HOME/.config/kitty/kitty.conf"
    copy_config "$base/catppuccin-mocha.conf"      "$TARGET_HOME/.config/kitty/catppuccin-mocha.conf"
}

# ----------------------------------------------------------------------------
#  deploy_ranger_config — copy the curated ranger file-manager config.
# ----------------------------------------------------------------------------
deploy_ranger_config() {
    info "Deploying ranger configuration (file manager)"
    copy_config "$SCRIPT_CONFIGS/ranger/rc.conf" "$TARGET_HOME/.config/ranger/rc.conf"
}

# ----------------------------------------------------------------------------
#  set_default_shell — make fish the login shell for the target user.
# ----------------------------------------------------------------------------
set_default_shell() {
    local shell_name="$1"
    local shell_path
    shell_path="$(command -v "$shell_name" 2>/dev/null || true)"

    if [[ "$DRY_RUN" == "true" ]]; then
        # fish is installed earlier in this same stage, so it does not exist
        # yet when running in preview mode.
        echo -e "  ${BLUE}[DRY]${NC} chsh -s $(command -v "$shell_name" 2>/dev/null || echo "/usr/bin/$shell_name") $TARGET_USER"
        return 0
    fi

    if [[ -z "$shell_path" ]]; then
        warn "$shell_name not found — skipping default shell change"
        return 1
    fi

    if [[ "$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f7)" == "$shell_path" ]]; then
        skip "Default shell is already $shell_name"
        return 0
    fi

    # Remember the previous login shell so --revert / r5 can restore it.
    # Written once; a re-run or a manual change keeps the first saved value.
    if [[ ! -f "$STATE_FILE.shell" ]]; then
        local current_shell
        current_shell="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f7)"
        if [[ -n "$current_shell" ]]; then
            echo "$current_shell" >"$STATE_FILE.shell"
            state_fix_owner
        fi
    fi

    if ! grep -qxF "$shell_path" /etc/shells 2>/dev/null; then
        # shellcheck disable=SC2016
        root_run sh -c 'echo "$1" >> /etc/shells' _ "$shell_path"
        info "Added $shell_path to /etc/shells"
    fi

    if root_run chsh -s "$shell_path" "$TARGET_USER"; then
        ok "Default shell set to $shell_name (relogin to apply)"
    else
        fail "Could not set default shell to $shell_name"
    fi
}