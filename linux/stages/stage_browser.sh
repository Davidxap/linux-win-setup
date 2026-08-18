#!/usr/bin/env bash
# ============================================================================
#  stage: browser — Pick your daily browser, then optionally drop Firefox.
#
#  A single browser is kept to avoid redundancy (Firefox ships with most
#  distros; Zen/Chrome/Brave are otherwise duplicated). Zen is the default.
# ============================================================================

stage_browser() {
    section "Browser" "Pick any or all browsers, then optionally remove Firefox."

    # ── Ask the user which browser(s) they want (multi-select: any or all) ──
    local choice
    choice="$(prompt_choice "Choose your browser(s) — comma list, or 'a' for all." \
        "Zen (Firefox-based) — recommended" \
        "Google Chrome (proprietary)" \
        "Brave (Chromium-based)" \
        "Helios (Firefox-based, privacy-focused)")"

    case "$choice" in
        all)
            info "Installing all browsers (Zen + Chrome + Brave + Helios)"
            flatpak_install "app.zen_browser.zen"
            flatpak_install "com.google.Chrome"
            flatpak_install "com.brave.Browser"
            flatpak_install "org.helios-browser.Heidi"
            ;;
        none)
            info "Skipping browser installation."
            ;;
        *)
            local n
            for n in $choice; do
                case "$n" in
                    1)
                        info "Installing Zen Browser (Flatpak)"
                        flatpak_install "app.zen_browser.zen"
                        ;;
                    2)
                        info "Installing Google Chrome (Flatpak)"
                        flatpak_install "com.google.Chrome"
                        ;;
                    3)
                        info "Installing Brave Browser (Flatpak)"
                        flatpak_install "com.brave.Browser"
                        ;;
                    4)
                        info "Installing Helios Browser (Flatpak)"
                        flatpak_install "org.helios-browser.Heidi"
                        ;;
                esac
            done
            ;;
    esac

    # ── Identify the preinstalled Firefox package on this distro ──
    local ff_pkg=""
    case "$(detect_family)" in
        fedora) pkg_installed firefox && ff_pkg="firefox" ;;
        debian)
            if pkg_installed firefox-esr; then ff_pkg="firefox-esr"
            elif pkg_installed firefox; then ff_pkg="firefox"; fi
            ;;
        arch)   pkg_installed firefox && ff_pkg="firefox" ;;
    esac

    # ── Offer Firefox removal only if it is actually installed ──
    if [[ -n "$ff_pkg" ]]; then
        if prompt_confirm "Remove $ff_pkg to keep a single browser?"; then
            info "Removing Firefox ($ff_pkg)"
            pkg_remove "$ff_pkg" || warn "Could not remove $ff_pkg (maybe it is a snap/flatpak)"
        else
            info "Keeping Firefox ($ff_pkg) — not touched."
        fi
    else
        info "Firefox is not installed on this system — nothing to remove."
    fi
}