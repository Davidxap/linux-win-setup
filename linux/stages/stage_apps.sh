#!/usr/bin/env bash
# ============================================================================
#  stage: apps — Flatpak desktop applications from Flathub.
#
#  The app list lives in manifests/apps-flatpak.txt so users can easily
#  remove or add apps without touching the code.
# ============================================================================

stage_apps() {
    section "Flatpak applications" "Sandboxed desktop apps from Flathub (auto-updated)."

    ensure_flatpak

    local manifest="$STAGE_LOCATION/../manifests/apps-flatpak.txt"
    if [[ ! -f "$manifest" ]]; then
        warn "Flatpak manifest not found: $manifest"
        return 0
    fi

    local app
    while read -r app; do
        [[ -z "$app" ]] && continue
        flatpak_install "$app"
    done < <(read_manifest "$manifest")
}