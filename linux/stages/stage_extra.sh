#!/usr/bin/env bash
# ============================================================================
#  stage: extra — Optional dev/AI/VM tools, multi-select checklist.
#
#  Installers that land in $HOME (Ollama, uv, fnm, pnpm, rustup) run as the
#  target user via run_as_user, so they end up in the right account even when
#  the script is executed with sudo.
#
#  Virtual machines: virt-manager and GNOME Boxes both need the QEMU/KVM
#  backend, which extra_vm_backend installs once per run. VirtualBox has its
#  own kernel modules and is installed as a separate package.
#
#  NOTE: npm is intentionally NOT offered here. The npm registry has had
#  supply-chain malware incidents, so this setup prefers standalone
#  installers + fnm/pnpm. If you really need npm, install it yourself.
# ============================================================================

stage_extra() {
    section "Optional extras" "Dev/AI tools you can opt into (multi-select)."

    echo -e "  ${DIM}Dev tools · AI agents · editors · API clients · password managers · VMs${NC}"
    echo -e "  ${YELLOW}Note: npm is not offered (supply-chain malware incidents).${NC}"
    echo ""

    local sel
    sel="$(prompt_multi_choice "Which extras do you want to install?" \
        "Ollama — run local LLMs (llama3, qwen, hermes3…)" \
        "opencode — AI coding agent in your terminal" \
        "Claude Code — Anthropic's AI coding agent" \
        "Gemini CLI — Google's AI coding agent" \
        "Codeium — AI coding agent / completions" \
        "uv — fast Python package manager" \
        "fnm + pnpm — Node manager + packages (npm-free)" \
        "rustup — Rust toolchain" \
        "pipx — install Python CLIs in isolated envs" \
        "VS Code — Microsoft's editor (Flatpak)" \
        "Cursor — AI-first editor (own installer)" \
        "Antigravity — Google's AI editor (own installer)" \
        "Postman — API client (REST/graphQL, Flatpak)" \
        "Insomnia — API client (REST/graphQL, Flatpak)" \
        "Bitwarden — password manager (Flatpak)" \
        "KeePassXC — offline password manager (Flatpak)" \
        "1Password — password manager (Flatpak)" \
        "Notion — notes & docs (Flatpak)" \
        "Mission Center — system monitor (Flatpak)" \
        "Bottles — run Windows apps/games (Flatpak)" \
        "virt-manager — KVM/QEMU virtual machines (GUI)" \
        "GNOME Boxes — KVM/QEMU virtual machines (simple GUI)" \
        "VirtualBox — Oracle VirtualBox (its own hypervisor)")"

    [[ -z "$sel" ]] && { info "No extras selected — skipping."; return 0; }

    local vm_backend_done=false
    local n
    for n in $sel; do
        case "$n" in
            1)  extra_ollama ;;
            2)  extra_opencode ;;
            3)  extra_claude_code ;;
            4)  extra_gemini_cli ;;
            5)  extra_codeium ;;
            6)  extra_uv ;;
            7)  extra_fnm_pnpm ;;
            8)  extra_rustup ;;
            9)  extra_pipx ;;
            10) extra_vscode ;;
            11) extra_cursor ;;
            12) extra_antigravity ;;
            13) extra_postman ;;
            14) extra_insomnia ;;
            15) extra_bitwarden ;;
            16) extra_keepassxc ;;
            17) extra_1password ;;
            18) extra_notion ;;
            19) extra_missioncenter ;;
            20) extra_bottles ;;
            21)
                if [[ "$vm_backend_done" != "true" ]]; then extra_vm_backend; vm_backend_done=true; fi
                extra_virt_manager
                ;;
            22)
                if [[ "$vm_backend_done" != "true" ]]; then extra_vm_backend; vm_backend_done=true; fi
                extra_gnome_boxes
                ;;
            23) extra_virtualbox ;;
        esac
    done
}

# ----------------------------------------------------------------------------
#  Individual extras. Each checks "already installed" before doing anything.
# ----------------------------------------------------------------------------
extra_ollama() {
    if command -v ollama &>/dev/null; then
        skip "Ollama"
        return 0
    fi
    info "Installing Ollama (user-level)"
    run_as_user "curl -fsSL https://ollama.com/install.sh | sh" \
        || fail "Ollama install failed"
    ok "Ollama installed — run 'ollama run llama3' to pull your first model"
}

extra_opencode() {
    if command -v opencode &>/dev/null; then
        skip "opencode"
        return 0
    fi
    info "Installing opencode (AI coding agent)"
    run_as_user "curl -fsSL https://opencode.ai/install | bash" \
        || fail "opencode install failed"
    ok "opencode installed — run 'opencode'"
}

# ----------------------------------------------------------------------------
#  AI coding agents (Claude Code, Gemini CLI, Codeium).
# ----------------------------------------------------------------------------
extra_claude_code() {
    if command -v claude &>/dev/null || [[ -x "$TARGET_HOME/.local/bin/claude" ]]; then
        skip "Claude Code"
        return 0
    fi
    info "Installing Claude Code (Anthropic AI coding agent)"
    run_as_user "curl -fsSL https://claude.ai/install.sh | bash" \
        || fail "Claude Code install failed"
    ok "Claude Code installed — run 'claude'"
}

extra_gemini_cli() {
    if command -v gemini &>/dev/null || [[ -x "$TARGET_HOME/.local/bin/gemini" ]]; then
        skip "Gemini CLI"
        return 0
    fi
    info "Installing Gemini CLI (Google AI coding agent)"
    run_as_user "curl -fsSL https://raw.githubusercontent.com/google-gemini/gemini-cli/main/install.sh | bash" \
        || warn "Gemini CLI install failed — manual install: https://github.com/google-gemini/gemini-cli"
    ok "Gemini CLI installed — run 'gemini'"
}

extra_codeium() {
    if command -v codeium &>/dev/null || [[ -x "$TARGET_HOME/.codeium/bin/codeium" ]]; then
        skip "Codeium"
        return 0
    fi
    info "Installing Codeium (AI coding agent / completions)"
    run_as_user "curl -fsSL https://codeium.com/install.sh | bash" \
        || warn "Codeium install failed — manual install: https://codeium.com"
    ok "Codeium installed — run 'codeium'"
}

# ----------------------------------------------------------------------------
#  Editors (VS Code, Cursor, Antigravity).
# ----------------------------------------------------------------------------
extra_vscode() {
    local app="com.visualstudio.code"
    if flatpak info "$app" &>/dev/null; then
        skip "VS Code"
        return 0
    fi
    info "Installing VS Code (Flatpak)"
    flatpak_install "$app"
}

extra_cursor() {
    if command -v cursor &>/dev/null || [[ -d "$TARGET_HOME/.cursor" ]]; then
        skip "Cursor"
        return 0
    fi
    info "Installing Cursor (AI-first editor)"
    # Cursor ships an official AppImage; we fetch the latest release URL.
    run_as_user "curl -fsSL https://www.cursor.com/api/download | bash -s -- linux-x64" \
        || warn "Cursor install failed — manual install: https://www.cursor.com"
    ok "Cursor installed — run 'cursor'"
}

extra_antigravity() {
    if command -v agy &>/dev/null || [[ -x "$TARGET_HOME/.local/bin/agy" ]]; then
        skip "Antigravity"
        return 0
    fi
    info "Installing Antigravity (Google AI editor, CLI binary 'agy')"
    run_as_user "curl -fsSL https://antigravity.google/cli/install.sh | bash" \
        || warn "Antigravity install failed — manual install: https://antigravity.google/docs/cli/install"
    ok "Antigravity installed — run 'agy'"
}

# ----------------------------------------------------------------------------
#  API clients (Postman, Insomnia).
# ----------------------------------------------------------------------------
extra_postman() {
    local app="com.getpostman.Postman"
    if flatpak info "$app" &>/dev/null; then
        skip "Postman"
        return 0
    fi
    info "Installing Postman (API client, Flatpak)"
    flatpak_install "$app"
}

extra_insomnia() {
    local app="rest.insomnia.Insomnia"
    if flatpak info "$app" &>/dev/null; then
        skip "Insomnia"
        return 0
    fi
    info "Installing Insomnia (API client, Flatpak)"
    flatpak_install "$app"
}

# ----------------------------------------------------------------------------
#  Password managers (KeePassXC, 1Password) + Notion.
# ----------------------------------------------------------------------------
extra_bitwarden() {
    local app="com.bitwarden.desktop"
    if flatpak info "$app" &>/dev/null; then
        skip "Bitwarden"
        return 0
    fi
    info "Installing Bitwarden (password manager, Flatpak)"
    flatpak_install "$app"
}

extra_keepassxc() {
    local app="org.keepassxc.KeePassXC"
    if flatpak info "$app" &>/dev/null; then
        skip "KeePassXC"
        return 0
    fi
    info "Installing KeePassXC (offline password manager, Flatpak)"
    flatpak_install "$app"
}

extra_1password() {
    local app="on.1password.OnePassword"
    if flatpak info "$app" &>/dev/null; then
        skip "1Password"
        return 0
    fi
    info "Installing 1Password (password manager, Flatpak)"
    flatpak_install "$app"
}

extra_notion() {
    local app="com.notion.Notion"
    if flatpak info "$app" &>/dev/null; then
        skip "Notion"
        return 0
    fi
    info "Installing Notion (notes & docs, Flatpak)"
    flatpak_install "$app"
}

extra_uv() {
    if command -v uv &>/dev/null; then
        skip "uv"
        return 0
    fi
    info "Installing uv (Python package manager)"
    run_as_user "curl -LsSf https://astral.sh/uv/install.sh | sh" \
        || fail "uv install failed"
    ok "uv installed — 'uv venv' / 'uvx'"
}

extra_fnm_pnpm() {
    if command -v fnm &>/dev/null; then
        skip "fnm"
    else
        info "Installing fnm (Node version manager)"
        run_as_user "curl -fsSL https://fnm.vercel.app/install | bash" \
            || fail "fnm install failed"
    fi

    if command -v pnpm &>/dev/null; then
        skip "pnpm"
    else
        info "Installing pnpm (Node packages, npm-free)"
        run_as_user "curl -fsSL https://get.pnpm.io/install.sh | sh" \
            || fail "pnpm install failed"
    fi
    ok "fnm + pnpm ready — 'fnm install --lts' then 'pnpm i'"
}

extra_rustup() {
    if command -v rustup &>/dev/null || [[ -x "$TARGET_HOME/.cargo/bin/rustup" ]]; then
        skip "rustup"
        return 0
    fi
    info "Installing rustup (Rust toolchain)"
    run_as_user "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y" \
        || fail "rustup install failed"
    ok "rustup installed — rust/cargo now available after relogin"
}

extra_pipx() {
    if command -v pipx &>/dev/null; then
        skip "pipx"
        return 0
    fi
    info "Installing pipx"
    record_installed pipx
    pkg_install pipx
    ok "pipx installed — 'pipx install <tool>'"
}

extra_missioncenter() {
    local app="io.missioncenter.MissionCenter"
    if flatpak info "$app" &>/dev/null; then
        skip "Mission Center"
        return 0
    fi
    info "Installing Mission Center (system monitor)"
    flatpak_install "$app"
}

extra_bottles() {
    local app="com.usebottles.bottles"
    if flatpak info "$app" &>/dev/null; then
        skip "Bottles"
        return 0
    fi
    info "Installing Bottles (Windows apps/games)"
    flatpak_install "$app"
}

# ----------------------------------------------------------------------------
#  Virtual machines.
#  virt-manager and GNOME Boxes are frontends on the KVM/QEMU backend, so they
#  share the packages installed by extra_vm_backend (libvirt + a QEMU build).
#  VirtualBox bundles its own hypervisor (kernel modules), no KVM needed.
# ----------------------------------------------------------------------------
extra_vm_backend() {
    local family
    family="$(detect_family)"
    local pkgs=()
    case "$family" in
        fedora) pkgs=(qemu-kvm libvirt virt-install) ;;
        debian) pkgs=(qemu-kvm libvirt-daemon-system qemu-utils) ;;
        arch)   pkgs=(qemu-full libvirt dnsmasq) ;;
        *)      warn "Unknown family '$family' — skipping KVM/QEMU backend" ; return 1 ;;
    esac

    info "Installing KVM/QEMU backend (libvirt + QEMU)"
    record_installed "${pkgs[@]}"
    pkg_install "${pkgs[@]}" || fail "KVM/QEMU backend install failed"

    if [[ "$DRY_RUN" != "true" ]] && [[ -d /run/systemd/system ]]; then
        info "Starting libvirtd (starts automatically on boot)"
        root_run systemctl enable --now libvirtd 2>/dev/null || true
    fi
    ok "KVM/QEMU backend ready"
}

extra_virt_manager() {
    if command -v virt-manager &>/dev/null; then
        skip "virt-manager"
        return 0
    fi
    local family
    family="$(detect_family)"
    case "$family" in
        fedora) pkg_install virt-manager ;;
        debian) pkg_install virt-manager ;;
        arch)   pkg_install virt-manager ;;
    esac
    record_installed virt-manager
    ok "virt-manager installed — launch it and connect to 'QEMU/KVM'"
}

extra_gnome_boxes() {
    local app="org.gnome.Boxes"
    if flatpak info "$app" &>/dev/null; then
        skip "GNOME Boxes"
        return 0
    fi
    info "Installing GNOME Boxes (Flatpak)"
    flatpak_install "$app"
}

extra_virtualbox() {
    if command -v VirtualBox &>/dev/null || [[ -d /opt/VirtualBox ]]; then
        skip "VirtualBox"
        return 0
    fi
    local family
    family="$(detect_family)"
    case "$family" in
        fedora)
            if pkg_installed VirtualBox; then
                skip "VirtualBox"
            else
                info "Installing VirtualBox (RPM Fusion nonfree)"
                pkg_install VirtualBox || warn "Install VirtualBox manually: sudo dnf install VirtualBox"
                record_installed VirtualBox
            fi
            ;;
        debian)
            if pkg_installed virtualbox; then
                skip "VirtualBox"
            else
                info "Installing VirtualBox (from Debian/Ubuntu repos)"
                pkg_install virtualbox virtualbox-dkms || warn "VirtualBox needs kernel headers — install manually if it fails"
                record_installed virtualbox virtualbox-dkms
            fi
            ;;
        arch)
            if pkg_installed virtualbox; then
                skip "VirtualBox"
            else
                info "Installing VirtualBox (from Arch repos)"
                pkg_install virtualbox virtualbox-host-dkms || warn "Rebuild kernel modules: sudo vboxreload"
                record_installed virtualbox virtualbox-host-dkms
            fi
            ;;
    esac
}
