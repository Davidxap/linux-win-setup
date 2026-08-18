#!/usr/bin/env bash
# ============================================================================
#  stage: revert — Undo everything the setup installs/configured.
#
#  This is the inverse of running `setup-linux.sh --all`. It:
#    - removes the Flatpak apps (apps-flatpak.txt + the optional extras)
#    - removes the Docker group membership + socket (native engine) or the
#      per-user service (Docker Desktop)
#    - removes the gaming tuning (systemd/udev/sysctl/profile.d/environment.d)
#    - removes the terminal configs (fish/kitty/ranger dotfiles we deployed)
#    - removes the $HOME extras (Ollama, opencode, uv, fnm+pnpm, rustup)
#    - removes the repositories the setup added (RPM Fusion, Docker CE, Flathub)
#
#  Package uninstall uses the install record written during setup
#  ($STATE_FILE.installed). Only packages the script itself installed are
#  removed — anything you already had is left alone. If no record exists (e.g.
#  the system was set up by an older version of the script) the user is asked
#  whether to fall back to removing the full base + gaming manifest lists.
#
#  PROTECTED_PACKAGES: packages the setup may install but which are NEVER
#  uninstalled by --revert (e.g. git, which is a core tool users rely on).
# ============================================================================

PROTECTED_PACKAGES="git"

# ----------------------------------------------------------------------------
#  revert_apps — remove the Flatpak desktop apps from apps-flatpak.txt.
# ----------------------------------------------------------------------------
revert_apps() {
    section "Revert: apps" "Remove Flatpak desktop applications from Flathub."

    local manifest="$STAGE_LOCATION/../manifests/apps-flatpak.txt"
    if [[ ! -f "$manifest" ]]; then
        warn "Flatpak manifest not found: $manifest"
        return 0
    fi

    local app
    while read -r app; do
        [[ -z "$app" ]] && continue
        flatpak_remove "$app"
    done < <(read_manifest "$manifest")
}

# ----------------------------------------------------------------------------
#  revert_packages — uninstall exactly what the setup installed, using the
#  install record written by record_installed() during setup. Packages you
#  already had before the setup are never touched.
#
#  If the record is missing (e.g. the machine was set up with an older version
#  of this script) the user is asked whether to fall back to removing the full
#  base + gaming manifest lists for this distro family.
# ----------------------------------------------------------------------------
revert_packages() {
    section "Revert: packages" "Uninstall system packages the setup installed."

    local family
    family="$(detect_family)"

    local pkgs=()
    mapfile -t pkgs < <(read_installed)
    if (( ${#pkgs[@]} == 0 )); then
        warn "No install record found ($STATE_FILE.installed missing)."
        echo -e "  ${YELLOW}Without a record I can only guess by removing the full${NC}"
        echo -e "  ${YELLOW}base + gaming package lists. This may also remove${NC}"
        echo -e "  ${YELLOW}packages you had installed BEFORE running this setup.${NC}"

        if [[ "$ASSUME_YES" != "true" ]] && tty_input; then
            if ! prompt_confirm "Remove the full base + gaming package lists?" n; then
                info "Skipped package uninstall."
                return 0
            fi
            echo ""
        fi

        mapfile -t pkgs < <(manifest_packages "$STAGE_LOCATION/../manifests/base-$family.txt" \
            "$STAGE_LOCATION/../manifests/gaming-$family.txt")
    fi

    if (( ${#pkgs[@]} == 0 )); then
        skip "No packages to remove"
        return 0
    fi

    local pkg failed=()
    for pkg in "${pkgs[@]}"; do
        [[ -z "$pkg" ]] && continue
        if grep -qw "$pkg" <<<"$PROTECTED_PACKAGES"; then
            skip "$pkg (protected - never uninstalled)"
            continue
        fi
        if pkg_installed "$pkg"; then
            if ! pkg_remove "$pkg"; then
                failed+=("$pkg")
            fi
        else
            skip "$pkg (not installed)"
        fi
    done

    if (( ${#failed[@]} != 0 )); then
        warn "${#failed[@]} package(s) could not be removed — ${failed[*]}"
        info "Some are needed by your desktop (e.g. GNOME/python3/gstreamer)."
        return 1
    fi
}

# ----------------------------------------------------------------------------
#  manifest_packages — concatenate the packages listed in the given manifests,
#  skipping blank lines and # comments. Falls back to that list when no
#  install record exists.
# ----------------------------------------------------------------------------
manifest_packages() {
    local manifest
    for manifest in "$@"; do
        if [[ -f "$manifest" ]]; then
            read_manifest "$manifest"
        else
            warn "Manifest not found: $manifest"
        fi
    done
}

# ----------------------------------------------------------------------------
#  revert_browser — remove the browsers the setup may have installed.
# ----------------------------------------------------------------------------
revert_browser() {
    section "Revert: browser" "Remove Zen / Chrome / Brave if they were installed."

    flatpak_remove "app.zen_browser.zen"
    flatpak_remove "com.google.Chrome"
    flatpak_remove "com.brave.Browser"
}

# ----------------------------------------------------------------------------
#  revert_gaming — undo GPU/systemd/udev/sysctl/profile.d/environment.d tuning.
# ----------------------------------------------------------------------------
revert_gaming() {
    section "Revert: gaming" "Remove systemd/udev/sysctl tuning + environment.d configs."

    local family
    family="$(detect_family)"

    # Systemd GPU performance units (installed by apply_gpu_systemd).
    local unit
    for unit in gpu-performance.service gpu-performance-watch.service gpu-performance-watch.path; do
        if [[ -f "/etc/systemd/system/$unit" ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                root_run systemctl disable --now "${unit%.*}" 2>/dev/null || true
                root_run systemctl disable --now "$unit" 2>/dev/null || true
            fi
            remove_path "/etc/systemd/system/$unit"
        fi
    done

    # udev rule (install_udev_rule).
    remove_path "/etc/udev/rules.d/99-amd-gpu-high.rules"

    # profile.d GameMode (install_profile_d).
    remove_path "/etc/profile.d/gamemode-gaming.sh"

    # sysctl files (apply_sysctl).
    remove_path "/etc/sysctl.d/99-sysctl.conf"
    remove_path "/etc/sysctl.d/99-swappiness.conf"
    remove_path "/etc/sysctl.d/99-hardening.conf"

    # environment.d user configs (install_env) — must go through copy_config
    # ownership handling, but for removal the file is simply deleted.
    remove_path "$TARGET_HOME/.config/environment.d/99-steam-wayland.conf"
    remove_path "$TARGET_HOME/.config/environment.d/fsr4-steam.conf"
    remove_path "$TARGET_HOME/.config/environment.d/steam-wayland.conf"
}

# ----------------------------------------------------------------------------
#  revert_docker — undo the Docker setup (group + socket / Desktop service).
#  The docker engine packages themselves are left installed.
# ----------------------------------------------------------------------------
revert_docker() {
    section "Revert: docker" "Remove the docker group + socket / Desktop service."

    if id -nG "$TARGET_USER" 2>/dev/null | grep -qw docker; then
        if [[ "$DRY_RUN" != "true" ]]; then
            root_run gpasswd -d "$TARGET_USER" docker 2>/dev/null \
                || warn "Could not remove $TARGET_USER from the docker group"
        fi
        ok "Removed $TARGET_USER from the docker group"
    else
        skip "docker group membership"
    fi

    if [[ -d /run/systemd/system ]] && [[ "$DRY_RUN" != "true" ]]; then
        root_run systemctl disable --now docker.socket 2>/dev/null || true
    fi
    ok "docker.socket disabled"

    if command -v docker-desktop &>/dev/null || [[ -d /opt/docker-desktop ]]; then
        if [[ "$DRY_RUN" != "true" ]]; then
            root_run systemctl --user disable --now docker-desktop 2>/dev/null || true
        fi
        ok "Docker Desktop service disabled"
    else
        skip "Docker Desktop"
    fi
}

# ----------------------------------------------------------------------------
#  revert_repos — remove the repositories the setup added.
# ----------------------------------------------------------------------------
revert_repos() {
    section "Revert: repos" "Remove RPM Fusion / Docker CE / Flathub."

    local family cmd
    family="$(detect_family)"
    cmd="$(pkg_cmd)"

    case "$family" in
        fedora)
            if rpm -q rpmfusion-free-release rpmfusion-nonfree-release &>/dev/null; then
                info "Removing RPM Fusion (free + nonfree)"
                pkg_run remove -y rpmfusion-free-release rpmfusion-nonfree-release
                ok "RPM Fusion repos removed"
            else
                skip "RPM Fusion repos"
            fi

            if "${cmd}" repolist 2>/dev/null | grep -q docker-ce-stable; then
                info "Removing Docker CE repo"
                if [[ "$DRY_RUN" != "true" ]]; then
                    root_run rm -f /etc/yum.repos.d/docker-ce.repo
                    root_run "${cmd}" clean all 2>/dev/null || true
                fi
                ok "Docker CE repo removed"
            else
                skip "Docker CE repo"
            fi
            ;;

        debian)
            if [[ -f /etc/apt/sources.list.d/docker.list ]]; then
                remove_path "/etc/apt/sources.list.d/docker.list"
                remove_path "/usr/share/keyrings/docker.gpg"
                pkg_run update
            else
                skip "Docker CE repo"
            fi
            ;;
    esac

    # Flathub: the setup adds it (ensure_flatpak) — remove it.
    if command -v flatpak &>/dev/null && flatpak remotes 2>/dev/null | grep -q flathub; then
        if [[ "$DRY_RUN" != "true" ]]; then
            runas_root flatpak remote-delete flathub 2>/dev/null || true
        fi
        ok "Flathub remote removed"
    else
        skip "Flathub remote"
    fi
}

# ----------------------------------------------------------------------------
#  revert_terminal — remove the fish/kitty/ranger dotfiles the setup deployed
#  and restore the login shell that existed before the setup changed it.
#  Leaves the terminal apps (fish, kitty) installed.
# ----------------------------------------------------------------------------
revert_terminal() {
    section "Revert: terminal" "Remove deployed fish / kitty / ranger configs + restore shell."

    remove_path "$TARGET_HOME/.config/fish/config.fish"
    remove_path "$TARGET_HOME/.config/fish/conf.d/colors.fish"
    remove_path "$TARGET_HOME/.config/fish/conf.d/rustup.fish"
    remove_path "$TARGET_HOME/.config/fish/conf.d/uv.env.fish"
    remove_path "$TARGET_HOME/.config/fish/completions/copilot.fish"
    remove_path "$TARGET_HOME/.config/kitty/kitty.conf"
    remove_path "$TARGET_HOME/.config/kitty/catppuccin-mocha.conf"
    remove_path "$TARGET_HOME/.config/ranger/rc.conf"
    remove_path "$TARGET_HOME/.zshrc"
    remove_path "$TARGET_HOME/.config/starship.toml"
    remove_path "$TARGET_HOME/.tmux.conf"

    restore_default_shell
}

# ----------------------------------------------------------------------------
#  restore_default_shell — put the user's login shell back to what it was
#  before the setup (saved by set_default_shell in $STATE_FILE.shell). Falls
#  back to bash when the saved value is missing or no longer exists.
# ----------------------------------------------------------------------------
restore_default_shell() {
    local prev current
    prev=""
    if [[ -f "$STATE_FILE.shell" ]]; then
        prev="$(cat "$STATE_FILE.shell" 2>/dev/null || true)"
    fi
    [[ -x "$prev" ]] || prev="/bin/bash"

    current="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f7)"
    if [[ "$current" == "$prev" ]]; then
        skip "Default shell is already $(basename "$prev")"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} chsh -s $prev $TARGET_USER"
        return 0
    fi

    if ! grep -qxF "$prev" /etc/shells 2>/dev/null; then
        # shellcheck disable=SC2016
        root_run sh -c 'echo "$1" >> /etc/shells' _ "$prev"
    fi

    if root_run chsh -s "$prev" "$TARGET_USER"; then
        ok "Default shell restored to $(basename "$prev") (relogin to apply)"
        rm -f "$STATE_FILE.shell"
        state_fix_owner
    else
        warn "Could not restore default shell — run: sudo chsh -s $prev $TARGET_USER"
    fi
}

# ----------------------------------------------------------------------------
#  strip_rc_lines — remove lines that the $HOME installers left behind in the
#  user's shell rc files (.bashrc / .bash_profile / .profile). Rustup sources
#  $HOME/.cargo/env, uv/fnm/pnpm/opencode export PATH entries, etc. These
#  lines break the shell once the tool dirs are gone ("No such file or
#  directory" on every prompt). Only exact/substring matches are removed.
# ----------------------------------------------------------------------------
strip_rc_lines() {
    local pattern="$1"
    local rc
    for rc in "$TARGET_HOME/.bashrc" "$TARGET_HOME/.bash_profile" "$TARGET_HOME/.profile"; do
        [[ -f "$rc" ]] || continue
        if grep -qF -- "$pattern" "$rc"; then
            if [[ "$DRY_RUN" != "true" ]]; then
                grep -vF -- "$pattern" "$rc" >"$rc.tmp" || true
                mv "$rc.tmp" "$rc"
                chown "$TARGET_USER:$TARGET_USER" "$rc" 2>/dev/null || true
            else
                echo -e "  ${BLUE}[DRY]${NC} strip '$pattern' from $rc"
            fi
        fi
    done
}

# ----------------------------------------------------------------------------
#  revert_extra — remove the $HOME extras installed by stage 'extra'.
# ----------------------------------------------------------------------------
revert_extra() {
    section "Revert: extras" "Remove $TARGET_HOME user-level tools (Ollama, uv, fnm…) + extra Flatpaks."

    # Extra Flatpak apps from stage 'extra' — they are not system packages,
    # so they are removed here rather than via the package record.
    flatpak_remove "io.missioncenter.MissionCenter"
    flatpak_remove "com.usebottles.bottles"
    flatpak_remove "org.gnome.Boxes"
    flatpak_remove "com.visualstudio.code"
    flatpak_remove "com.getpostman.Postman"
    flatpak_remove "rest.insomnia.Insomnia"
    flatpak_remove "com.bitwarden.desktop"
    flatpak_remove "org.keepassxc.KeePassXC"
    flatpak_remove "on.1password.OnePassword"
    flatpak_remove "com.notion.Notion"

    # Ollama (extra_ollama) installs into ~/.ollama + ~/.local/bin/ollama,
    # and the installer also drops /usr/local/bin/ollama + a systemd service.
    remove_path "$TARGET_HOME/.ollama"
    remove_path "$TARGET_HOME/.local/bin/ollama"
    remove_path "/usr/local/bin/ollama"
    remove_path "/etc/systemd/system/ollama.service"
    if [[ "$DRY_RUN" != "true" ]] && [[ -d /run/systemd/system ]]; then
        root_run systemctl disable --now ollama 2>/dev/null || true
    fi

    # opencode (extra_opencode) installs into ~/.opencode + ~/.local/bin.
    remove_path "$TARGET_HOME/.opencode"
    remove_path "$TARGET_HOME/.local/bin/opencode"

    # Claude Code (extra_claude_code) → ~/.local/bin/claude + ~/.claude.
    remove_path "$TARGET_HOME/.claude"
    remove_path "$TARGET_HOME/.local/bin/claude"

    # Gemini CLI (extra_gemini_cli) → ~/.local/bin/gemini + ~/.gemini.
    remove_path "$TARGET_HOME/.gemini"
    remove_path "$TARGET_HOME/.local/bin/gemini"

    # Codeium (extra_codeium) → ~/.codeium.
    remove_path "$TARGET_HOME/.codeium"

    # Cursor (extra_cursor) → ~/.cursor + AppImage in ~/Applications.
    remove_path "$TARGET_HOME/.cursor"
    remove_path "$TARGET_HOME/Applications/cursor"

    # Antigravity (extra_antigravity) → ~/.antigravity.
    remove_path "$TARGET_HOME/.antigravity"

    # uv (extra_uv) installs into ~/.local/bin/uv + ~/.cache/uv.
    remove_path "$TARGET_HOME/.local/bin/uv"
    remove_path "$TARGET_HOME/.local/bin/uvx"
    remove_path "$TARGET_HOME/.cache/uv"

    # fnm (extra_fnm_pnpm) → ~/.local/share/fnm ; pnpm → ~/.local/share/pnpm.
    remove_path "$TARGET_HOME/.local/share/fnm"
    remove_path "$TARGET_HOME/.local/share/pnpm"

    # rustup (extra_rustup) → ~/.cargo + ~/.rustup.
    remove_path "$TARGET_HOME/.cargo"
    remove_path "$TARGET_HOME/.rustup"

    # Clean up the PATH/source lines the $HOME installers appended to the
    # shell rc files, so the next prompt doesn't error on missing dirs.
    strip_rc_lines ".cargo/env"
    strip_rc_lines "fnm"
    strip_rc_lines "PNPM_HOME"
    strip_rc_lines ".local/share/pnpm"
    strip_rc_lines ".local/bin/uv"
    strip_rc_lines ".opencode"
    strip_rc_lines ".local/bin/opencode"
    strip_rc_lines ".local/bin/claude"
    strip_rc_lines ".local/bin/gemini"
    strip_rc_lines "codeium"
    strip_rc_lines "antigravity"
    strip_rc_lines ".local/bin/agy"
}

# ----------------------------------------------------------------------------
#  stage_revert — run every revert_* in order. Called via --revert.
# ----------------------------------------------------------------------------
stage_revert() {
    section "Uninstall" "Undo everything linux-win-setup installed or configured."

    echo -e "  ${YELLOW}This will remove the Flatpak apps, installed packages,${NC}"
    echo -e "  ${YELLOW}Docker setup, gaming tuning, repos and terminal configs.${NC}"
    echo -e "  ${DIM}Only what this setup installed is removed — pre-existing${NC}"
    echo -e "  ${DIM}packages are kept (see --revert fallback for old installs).${NC}"
    echo ""

    if [[ "$ASSUME_YES" != "true" ]] && tty_input; then
        if ! prompt_confirm "Really undo the whole setup?" n; then
            info "Revert aborted."
            return 1
        fi
        echo ""
    fi

    # Reverse of the install order, so configs are removed after the apps
    # that depend on them are gone, and repos are dropped only after every
    # package that needs them has been uninstalled.
    local rc=0
    revert_apps
    revert_browser
    revert_extra
    revert_gaming
    revert_terminal
    revert_packages || rc=1
    revert_docker
    revert_repos

    echo ""
    if [[ $rc -eq 0 ]]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}  ✓ Uninstall complete${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}  ⚠ Uninstall finished with warnings${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${YELLOW}Some packages could not be removed (desktop dependencies).${NC}"
        echo -e "  ${YELLOW}Remove them manually if you really want them gone:${NC}"
        echo -e "  ${YELLOW}  sudo dnf remove gstreamer1-plugins-base gstreamer1-plugins-good python3${NC}"
    fi
    echo ""
    echo -e "  ${YELLOW}Log out & back in so the docker group / environment${NC}"
    echo -e "  ${YELLOW}changes are fully applied.${NC}"
    echo ""
    return $rc
}
