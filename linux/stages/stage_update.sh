#!/usr/bin/env bash
# ============================================================================
#  stage: update — Bring the whole system (packages + flatpaks) up to date.
# ============================================================================

stage_update() {
    section "System update" "Refresh package lists and apply all available upgrades."

    info "Updating system packages..."
    if pkg_update; then
        ok "Package index refreshed"
    else
        fail "Package index refresh failed"
    fi

    info "Applying upgrades..."
    if pkg_upgrade; then
        ok "System packages upgraded"
    else
        fail "System package upgrade failed"
    fi

    if command -v flatpak &>/dev/null; then
        info "Updating flatpak applications..."
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${BLUE}[DRY]${NC} flatpak update -y"
        else
            local fp_out fp_code
            fp_out="$(flatpak update -y 2>&1)"; fp_code=$?
            # Known non-fatal glitch: a stale appstream cache can fail with
            # "Error moving file ... File exists". Retry once; if that still
            # trips on the same error, treat it as success (apps update fine
            # next run).
            if (( fp_code != 0 )) && grep -q "File exists" <<<"$fp_out"; then
                fp_out="$(flatpak update -y 2>&1)"; fp_code=$?
            fi
            if (( fp_code == 0 )); then
                ok "Flatpaks updated"
            elif grep -q "File exists" <<<"$fp_out"; then
                warn "Flatpak appstream cache glitch (File exists) — will self-heal next update"
                ok "Flatpaks updated"
            else
                fail "Flatpak update failed"
            fi
        fi
    else
        skip "Flatpak not installed yet (stage 'repos' adds it)"
    fi
}