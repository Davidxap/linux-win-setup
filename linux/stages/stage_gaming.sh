#!/usr/bin/env bash
# ============================================================================
#  stage: gaming — Install the gaming stack and apply AMD tuning.
#
#  The heavy lifting comes from the config files in linux/configs/
#  (systemd, udev, sysctl, environment.d). The AMD-specific pieces only run
#  when an AMD GPU is detected on a real Linux box (not WSL/container).
# ============================================================================

stage_gaming() {
    section "Gaming" "Install the gaming stack and apply (AMD) performance tuning."

    # ── Install the gaming packages listed for this distro family ──
    local family manifest
    family="$(detect_family)"
    manifest="$SCRIPT_CONFIGS/../manifests/gaming-${family}.txt"

    if [[ -f "$manifest" ]]; then
        local pkg missing=()
        while read -r pkg; do
            [[ -z "$pkg" ]] && continue
            pkg_installed "$pkg" || missing+=("$pkg")
        done < <(read_manifest "$manifest")

        if (( ${#missing[@]} == 0 )); then
            ok "Gaming packages already installed"
        else
            echo -e "  ${CYAN}Installing gaming packages...${NC}"
            record_installed "${missing[@]}"
            pkg_install "${missing[@]}"
        fi
    else
        warn "No gaming manifest for family '$family'"
    fi

    # ── Ask the user which GPU vendor to tune for (AMD is the default) ──
    local gpu_choice
    gpu_choice="$(prompt_choice "Which GPU vendor should this box be tuned for?" \
        "AMD (Radeon)" \
        "NVIDIA" \
        "Intel (Arc / Iris)" \
        "Skip GPU-specific tuning")"

    case "$gpu_choice" in
        all)
            tune_gpu_amd
            ;;
        none)
            warn "Skipping GPU-specific tuning."
            ;;
        *)
            local n
            for n in $gpu_choice; do
                case "$n" in
                    1) tune_gpu_amd ;;
                    2) tune_gpu_nvidia ;;
                    3) tune_gpu_intel ;;
                    4) warn "Skipping GPU-specific tuning." ;;
                esac
            done
            ;;
    esac

    # ── The rest applies regardless of GPU vendor, on any KDE/Wayland box ──
    install_env
    install_profile_d
    apply_sysctl
}

# ----------------------------------------------------------------------------
#  tune_gpu_amd — amdgpu power-pinning (systemd + udev) for the known
#  stutter bug where the GPU drops to 112 MHz and KWin reports atomic commits.
# ----------------------------------------------------------------------------
tune_gpu_amd() {
    info "AMD GPU selected → applying amdgpu performance tuning"
    apply_gpu_systemd    # systemd unit that pins GPU power to 'high'
    install_udev_rule    # kernel-level fallback, independent of systemd
}

# ----------------------------------------------------------------------------
#  tune_gpu_nvidia — proprietary driver path: no amdgpu pieces apply; we
#  simply document the layout and keep GameMode/fsynced env for Proton.
# ----------------------------------------------------------------------------
tune_gpu_nvidia() {
    info "NVIDIA selected — no amdgpu-specific tuning needed."
    warn "Install the NVIDIA proprietary driver through your distro's recommended"
    warn "  path (dnf install akmod-nvidia / nvidia-detect, or apt install nvidia-driver)."
    warn "  GameMode + PROTON_ENABLE_GAMEMODE=1 are still applied for Proton games."
}

# ----------------------------------------------------------------------------
#  tune_gpu_intel — Arc/Iris are fine on stock settings; the shared GameMode
#  and sysctl tuning still apply.
# ----------------------------------------------------------------------------
tune_gpu_intel() {
    info "Intel GPU selected — stock graphics settings are recommended."
    info "  Enabling GameMode + shared sysctl tuning for smoother play."
}

# ----------------------------------------------------------------------------
#  apply_gpu_systemd — systemd units that pin amdgpu performance to 'high'.
#  Prevents the known stutter bug where the GPU drops to 112 MHz and KWin
#  reports "atomic commit failed".
# ----------------------------------------------------------------------------
apply_gpu_systemd() {
    if [[ ! -d /run/systemd/system ]]; then
        info "No systemd — skipping GPU performance units (WSL/container)."
        return 0
    fi

    local src="$SCRIPT_CONFIGS/systemd"
    info "Installing GPU performance systemd unit (amdgpu → 'high')"
    root_run cp "$src/gpu-performance.service"        /etc/systemd/system/
    root_run cp "$src/gpu-performance-watch.path"     /etc/systemd/system/
    root_run cp "$src/gpu-performance-watch.service"  /etc/systemd/system/

    if [[ "$DRY_RUN" != "true" ]]; then
        root_run systemctl daemon-reload
        root_run systemctl enable --now gpu-performance.service       2>/dev/null || true
        root_run systemctl enable --now gpu-performance-watch.path    2>/dev/null || true
    fi
    ok "GPU performance service + watchdog enabled"
}

# ----------------------------------------------------------------------------
#  install_udev_rule — kernel-level safety net: forces 'high' power level.
# ----------------------------------------------------------------------------
install_udev_rule() {
    info "Installing udev rule (GPU 'high' power profile from the kernel)"
    root_run cp "$SCRIPT_CONFIGS/udev/99-amd-gpu-high.rules" /etc/udev/rules.d/
    if [[ "$DRY_RUN" != "true" ]]; then
        root_run udevadm control --reload-rules 2>/dev/null || true
        root_run udevadm trigger 2>/dev/null || true
    fi
    ok "udev rule installed"
}

# ----------------------------------------------------------------------------
#  install_env — user & environment variables for Steam/Wayland/FSR4.
# ----------------------------------------------------------------------------
install_env() {
    local base="$SCRIPT_CONFIGS/environment.d"
    info "Deploying environment variables (Steam Wayland, FSR4, RADV)"
    copy_config "$base/99-steam-wayland.conf"  "$TARGET_HOME/.config/environment.d/99-steam-wayland.conf"
    copy_config "$base/fsr4-steam.conf"        "$TARGET_HOME/.config/environment.d/fsr4-steam.conf"
    copy_config "$base/steam-wayland.conf"     "$TARGET_HOME/.config/environment.d/steam-wayland.conf"
    info "These variables apply from the next login session."
}

# ----------------------------------------------------------------------------
#  install_profile_d — GameMode enabled for every session.
# ----------------------------------------------------------------------------
install_profile_d() {
    info "Enabling GameMode by default (PROTON_ENABLE_GAMEMODE=1)"
    root_run cp "$SCRIPT_CONFIGS/profile.d/gamemode-gaming.sh" /etc/profile.d/
    if [[ "$DRY_RUN" != "true" ]]; then
        root_run chmod +x /etc/profile.d/gamemode-gaming.sh
    fi
    ok "GameMode profile applied"
}

# ----------------------------------------------------------------------------
#  apply_sysctl — swappiness, inotify limits & kernel hardening.
# ----------------------------------------------------------------------------
apply_sysctl() {
    info "Applying sysctl tuning (swappiness, inotify, hardening)"
    root_run cp "$SCRIPT_CONFIGS/sysctl/99-sysctl.conf"     /etc/sysctl.d/
    root_run cp "$SCRIPT_CONFIGS/sysctl/99-swappiness.conf" /etc/sysctl.d/
    root_run cp "$SCRIPT_CONFIGS/sysctl/99-hardening.conf"       /etc/sysctl.d/
    if [[ "$DRY_RUN" != "true" ]]; then
        root_run sysctl --system 2>/dev/null || true
    fi
    ok "sysctl applied"
}