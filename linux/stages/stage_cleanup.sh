#!/usr/bin/env bash
# ============================================================================
#  stage: cleanup — Remove leftovers after a fresh installation.
#
#  Keenies: orphaned dependencies (autoremove) + flathub runtimes no app
#  references anymore. Safe to run at any time.
# ============================================================================

stage_cleanup() {
    section "Final cleanup" "Remove orphaned packages and unused flatpak runtimes."

    info "Removing orphaned dependencies..."
    if pkg_cleanup; then
        ok "Orphaned dependencies removed"
    else
        warn "Nothing to do on the package side"
    fi

    if command -v flatpak &>/dev/null; then
        info "Removing unused flatpak runtimes..."
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${BLUE}[DRY]${NC} flatpak uninstall --unused -y"
        elif flatpak uninstall --unused -y 2>&1 | tail -n 2; then
            ok "Unused flatpaks removed"
        else
            skip "No unused flatpaks"
        fi
    fi

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  ✓ Setup complete${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${YELLOW}Logout & log back in so fish, the docker group and the${NC}"
    echo -e "  ${YELLOW}gaming environment variables take effect.${NC}"
    echo ""
}