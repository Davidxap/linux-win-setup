#!/usr/bin/env bash
# ============================================================================
#  stage: docker — Docker engine or Docker Desktop (you choose).
#
#  Options:
#    [1] Native engine (recommended) — docker-ce + on-demand socket + group
#    [2] Docker Desktop            — official GUI app (ships its own engine)
#    [3] Skip
#
#  Docker Desktop is a desktop application with its own VM-backed engine; it
#  is an *alternative* to the native engine, not an add-on. It needs KVM and
#  a graphical session. Selecting it skips the native engine entirely.
# ============================================================================

stage_docker() {
    section "Docker" "Native engine or Docker Desktop — you choose."

    if command -v docker-desktop &>/dev/null || [[ -d /opt/docker-desktop ]]; then
        info "Docker Desktop already installed."
        docker_desktop_post
        return 0
    fi

    local choice
    choice="$(prompt_choice "How do you want Docker installed?" \
        "Native engine (recommended, no GUI)" \
        "Docker Desktop (official GUI app)" \
        "Skip Docker setup")"

    case "$choice" in
        all)
            docker_native
            ;;
        none)
            info "Docker setup skipped."
            ;;
        *)
            local n
            for n in $choice; do
                case "$n" in
                    1) docker_native ;;
                    2) docker_desktop ;;
                    3) info "Docker setup skipped." ;;
                esac
            done
            ;;
    esac
}

# ----------------------------------------------------------------------------
#  docker_native — the classic engine: docker-ce, socket on demand, group.
# ----------------------------------------------------------------------------
docker_native() {
    # On Fedora the engine comes from the base manifest (stage 'packages').
    local family
    family="$(detect_family)"

    if ! command -v docker &>/dev/null; then
        info "Installing Docker engine"
        case "$family" in
            fedora) pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                    record_installed docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin ;;
            debian) pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                    record_installed docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin ;;
            arch)   pkg_install docker docker-buildx docker-compose
                    record_installed docker docker-buildx docker-compose ;;
        esac
    else
        skip "Docker engine"
    fi

    # ── Enable the socket (starts dockerd on demand) ──
    if [[ -d /run/systemd/system ]]; then
        info "Enabling docker.socket (on-demand start)"
        if [[ "$DRY_RUN" != "true" ]]; then
            root_run systemctl enable docker.socket 2>/dev/null || true
            root_run systemctl start  docker.socket 2>/dev/null || true
        fi
        ok "docker.socket enabled"
    else
        info "No systemd — Docker socket is started by WSL/other means."
    fi

    # ── Add the target user to the docker group ──
    if id -nG "$TARGET_USER" 2>/dev/null | grep -qw docker; then
        skip "User already in docker group"
    else
        info "Adding $TARGET_USER to the docker group (works after relogin)"
        root_run usermod -aG docker "$TARGET_USER"
    fi
}

# ----------------------------------------------------------------------------
#  docker_desktop — official Docker Desktop app for Linux.
#  Downloads the .deb/.rpm (latest) from desktop.docker.com and installs it.
#  Docker Desktop bundles its own engine, so nothing native is installed here.
# ----------------------------------------------------------------------------
docker_desktop() {
    local family
    family="$(detect_family)"

    if [[ "$family" == "arch" ]]; then
        info "Docker Desktop on Arch is installed from the AUR (docker-desktop)."
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${BLUE}[DRY]${NC} paru -S docker-desktop (or your preferred AUR helper)"
            return 0
        fi
        if command -v paru &>/dev/null; then
            runas_root paru -S --noconfirm docker-desktop || warn "AUR install failed"
        elif command -v yay &>/dev/null; then
            runas_root yay -S --noconfirm docker-desktop || warn "AUR install failed"
        else
            warn "No AUR helper found (paru/yay). Install docker-desktop manually."
            return 1
        fi
        docker_desktop_post
        return 0
    fi

    if [[ "$family" != "fedora" && "$family" != "debian" ]]; then
        warn "Docker Desktop is not auto-installed on '$family'. Install it manually."
        return 1
    fi

    if ! [[ -e /dev/kvm ]]; then
        warn "No /dev/kvm found — Docker Desktop needs KVM to run its VM."
        info "Install KVM first (e.g. dnf install @virtualization), then re-run."
        return 1
    fi

    local url pkg
    if [[ "$family" == "fedora" ]]; then
        url="https://desktop.docker.com/linux/main/amd64/docker-desktop-x86_64.rpm"
        pkg="/tmp/docker-desktop.rpm"
    else
        url="https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb"
        pkg="/tmp/docker-desktop.deb"
    fi

    info "Downloading Docker Desktop (latest)..."
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} curl -fsSL -o $pkg $url"
        echo -e "  ${BLUE}[DRY]${NC} root: $(pkg_cmd) install -y $pkg"
        echo -e "  ${BLUE}[DRY]${NC} systemctl --user enable --now docker-desktop"
        docker_desktop_post
        return 0
    fi

    if ! runas_root curl -fsSL -o "$pkg" "$url"; then
        fail "Could not download Docker Desktop from $url"
        return 1
    fi
    ok "Downloaded Docker Desktop package"

    info "Installing Docker Desktop..."
    if runas_root "$(pkg_cmd)" install -y "$pkg" 2>&1 | tail -n 3; then
        ok "Docker Desktop installed"
    else
        fail "Docker Desktop install failed"
        return 1
    fi

    docker_desktop_post
}

# ----------------------------------------------------------------------------
#  docker_desktop_post — shared post-install for Docker Desktop:
#  enable the per-user service + provide a plain `docker` alias/launcher note.
# ----------------------------------------------------------------------------
docker_desktop_post() {
    # Docker Desktop runs as a per-user systemd service. Enable it so the
    # `docker` CLI works from the terminal even before the GUI is opened.
    if [[ -d /run/systemd/system ]] && [[ -d /run/user/"$(id -u "$TARGET_USER")"/systemd ]]; then
        info "Enabling per-user docker-desktop service"
        if [[ "$DRY_RUN" != "true" ]]; then
            runas_root systemctl --user enable --now docker-desktop 2>/dev/null \
                || warn "Could not enable docker-desktop service (start the GUI manually)"
        fi
    fi

    # The desktop app installs a `docker-desktop` command; give the user a hint.
    info "Launch Docker Desktop from the app menu, or run: docker-desktop"
}
