#!/usr/bin/env bash
# ============================================================================
#  stage: browser — Pick your daily browser(s), then optionally drop Firefox.
#
#  A single browser is kept to avoid redundancy (Firefox ships with most
#  distros; the others are otherwise duplicated). Zen is the default.
#  Helium is not on Flathub, so it is installed natively per distro.
# ============================================================================

# Install Helium natively (it is not published on Flathub).
helium_install() {
    if command -v helium &>/dev/null; then
        skip "Helium (already installed)"
        return 0
    fi
    case "$(detect_family)" in
        fedora)
            if spinner "Enabling Helium COPR" runas_root dnf copr enable -y imput/helium; then
                pkg_install helium-bin
            else
                warn "Could not enable Helium COPR"
            fi
            ;;
        debian)
            # Official Debian/Ubuntu repo: keyring + signed apt source.
            if spinner "Adding Helium apt repository" runas_root bash -c '
                curl -fsSL https://pkg.helium.computer/pubkey.asc | gpg --dearmor -o /usr/share/keyrings/helium.gpg
                echo "deb [signed-by=/usr/share/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main" > /etc/apt/sources.list.d/helium.list
                apt-get update -qq
            '; then
                pkg_install helium-bin
            else
                warn "Could not add Helium apt repository"
            fi
            ;;
        arch)
            local helper=""
            for h in paru yay; do command -v "$h" &>/dev/null && helper="$h" && break; done
            if [[ -n "$helper" ]]; then
                spinner "Installing Helium (AUR: helium-bin)" runas_root "$helper" -S --noconfirm helium-bin
            else
                warn "No AUR helper (paru/yay) found — install helium-bin from the AUR manually"
            fi
            ;;
        *)
            warn "Helium not available for this distro — install from helium.computer/download"
            ;;
    esac
}

stage_browser() {
    section "Browser" "Pick any or all browsers, then optionally remove Firefox."

    # ── Ask the user which browser(s) they want (multi-select: any or all) ──
    local choice
    choice="$(prompt_choice "Choose your browser(s) — comma list, or 'a' for all." \
        "Zen (Firefox-based) — recommended" \
        "Google Chrome (proprietary)" \
        "Brave (Chromium-based)" \
        "Helium (Chromium-based, privacy-focused)" \
        "Firefox (Mozilla)" \
        "LibreWolf (Firefox fork, privacy)")"

    case "$choice" in
        all)
            info "Installing all browsers (Zen + Chrome + Brave + Helium + Firefox + LibreWolf)"
            flatpak_install "app.zen_browser.zen"
            flatpak_install "com.google.Chrome"
            flatpak_install "com.brave.Browser"
            helium_install
            flatpak_install "org.mozilla.firefox"
            flatpak_install "io.gitlab.librewolf-community"
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
                        info "Installing Helium (native)"
                        helium_install
                        ;;
                    5)
                        info "Installing Firefox (Flatpak)"
                        flatpak_install "org.mozilla.firefox"
                        ;;
                    6)
                        info "Installing LibreWolf (Flatpak)"
                        flatpak_install "io.gitlab.librewolf-community"
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