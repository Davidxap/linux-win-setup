#!/usr/bin/env bash
# ============================================================================
#  stage: packages — Install the base system packages (CLI tools, codecs...).
#
#  The concrete list comes from the manifest that matches your distro family:
#    manifests/base-fedora.txt  manifests/base-debian.txt  manifests/base-arch.txt
#  Only missing packages are installed (idempotent and safe to re-run).
#  dnf5/apt/pacman show their own real-time progress bar during the batch.
# ============================================================================

stage_packages() {
    section "Base packages" "Install the daily-driver CLI tools for your distro."

    local family manifest
    family="$(detect_family)"
    manifest="$STAGE_LOCATION/../manifests/base-${family}.txt"

    if [[ ! -f "$manifest" ]]; then
        warn "No base manifest for family '$family' (expected $manifest). Skipping."
        return 0
    fi

    # Collect the packages that are missing on this machine, then install in
    # a single batch so the package manager can print one progress bar.
    # Packages that do not exist in the repos (obsoleted/renamed) are skipped
    # with a warning instead of failing the whole batch.
    local pkg missing=() unavailable=()
    while read -r pkg; do
        [[ -z "$pkg" ]] && continue
        # On Fedora the full `ffmpeg` (RPM Fusion) replaces the distro's
        # `ffmpeg-free` libs, which dnf only allows with --allowerasing.
        # Install it on its own so the rest of the batch never fails.
        if [[ "$pkg" == "ffmpeg" ]] && [[ "$(detect_family)" == "fedora" ]]; then
            if ! pkg_installed "$pkg"; then
                info "ffmpeg replaces Fedora's ffmpeg-free libs (RPM Fusion --allowerasing)"
                record_installed ffmpeg
                pkg_install_erase ffmpeg || fail "Could not install ffmpeg"
            fi
            continue
        fi
        if pkg_installed "$pkg"; then
            continue
        fi
        if pkg_available "$pkg"; then
            missing+=("$pkg")
        else
            unavailable+=("$pkg")
        fi
    done < <(read_manifest "$manifest")

    if (( ${#unavailable[@]} > 0 )); then
        warn "Skipping ${#unavailable[@]} package(s) not in the repos: ${unavailable[*]}"
    fi

    if (( ${#missing[@]} == 0 )); then
        ok "All base packages already installed"
        return 0
    fi

    echo -e "  ${CYAN}Installing ${#missing[@]} package(s)...${NC}"
    record_installed "${missing[@]}"
    if pkg_install "${missing[@]}"; then
        ok "Base packages installed (${#missing[@]})"
    else
        fail "Some packages failed — check the log: $LOG_FILE"
    fi
}