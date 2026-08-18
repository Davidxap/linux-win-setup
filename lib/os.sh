#!/usr/bin/env bash
# ============================================================================
#  lib/os.sh — OS/distro detection + unified package-manager wrappers.
#
#  The whole repo is multi-distro by design. This file abstracts the OS
#  differences so the stage scripts never call dnf5/apt/pacman directly.
# ============================================================================

# Resolve the real user when the script is invoked with `sudo`.
TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"
TARGET_HOME="$(eval echo "~$TARGET_USER")"
TARGET_HOME="${TARGET_HOME:-$HOME}"

# ----------------------------------------------------------------------------
#  detect_system — linux / wsl / windows / unknown
#  WSL is detected through the kernel string containing "microsoft".
# ----------------------------------------------------------------------------
detect_system() {
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [[ "$(uname -s 2>/dev/null)" == "Linux" ]]; then
        echo "linux"
    elif command -v cmd.exe &>/dev/null || [[ -n "${WINDIR:-}" || -n "${OS:-}" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# ----------------------------------------------------------------------------
#  detect_distro — full distro ID from /etc/os-release (fedora, ubuntu, arch).
# ----------------------------------------------------------------------------
detect_distro() {
    local id=""
    if [[ -f /etc/os-release ]]; then
        id="$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"' | head -1)"
    fi
    echo "${id:-unknown}"
}

# ----------------------------------------------------------------------------
#  detect_family — groups distros into the three package systems we support.
# ----------------------------------------------------------------------------
detect_family() {
    local id
    id="$(detect_distro)"
    case "$id" in
        fedora|centos|rhel|rocky|almalinux) echo "fedora" ;;
        debian|ubuntu|pop|linuxmint|elementary|kali) echo "debian" ;;
        arch|endeavouros|manjaro|arcolinux|cachyos) echo "arch" ;;
        *) echo "unknown" ;;
    esac
}

# ----------------------------------------------------------------------------
#  pkg_cmd — name of the native package manager to use.
# ----------------------------------------------------------------------------
pkg_cmd() {
    case "$(detect_family)" in
        fedora)
            if command -v dnf5 &>/dev/null; then echo "dnf5"; else echo "dnf"; fi
            ;;
        debian) echo "apt-get" ;;
        arch)   echo "pacman" ;;
        *)      echo "unknown" ;;
    esac
}

# ----------------------------------------------------------------------------
#  runas_root — prefix a command with sudo unless we already are root.
# ----------------------------------------------------------------------------
runas_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# ----------------------------------------------------------------------------
#  pkg_installed — true if the package is already installed.
#  Handles multi-arch suffixes (e.g. foo.i686) and globs.
# ----------------------------------------------------------------------------
pkg_installed() {
    local pkg="$1"
    local pkg_stripped="${pkg%.i686}"
    case "$(detect_family)" in
        fedora) rpm -q --whatprovides "$pkg_stripped" &>/dev/null ;;
        debian) dpkg-query -W -f='${Status}' "$pkg_stripped" 2>/dev/null | grep -q "install ok installed" ;;
        arch)   pacman -Qq "$pkg_stripped" &>/dev/null ;;
        *)      return 1 ;;
    esac
}

# ----------------------------------------------------------------------------
#  pkg_available — true if the package exists in the configured repositories.
#  Used to skip packages that are missing/obsoleted instead of failing the
#  whole batch (e.g. 'unrar' on distros where it was dropped).
# ----------------------------------------------------------------------------
pkg_available() {
    local pkg="$1"
    case "$(detect_family)" in
        fedora) dnf list --available "$pkg" &>/dev/null || dnf list --installed "$pkg" &>/dev/null ;;
        debian) apt-cache show "$pkg" &>/dev/null ;;
        arch)   pacman -Si "$pkg" &>/dev/null ;;
        *)      return 1 ;;
    esac
}

# ----------------------------------------------------------------------------
#  pkg_install — install packages with the native manager.
#  `pkg_install "a b c"` or `pkg_install a b c`.
# ----------------------------------------------------------------------------
pkg_install() {
    local pkgs=("$@")
    local cmd
    cmd="$(pkg_cmd)"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} $cmd install -y ${pkgs[*]}"
        return 0
    fi

    local ok=true
    case "$cmd" in
        dnf5|dnf)
            spinner "Installing ${#pkgs[@]} package(s)" runas_root "$cmd" install -y "${pkgs[@]}" || ok=false
            ;;
        apt-get)
            spinner "Installing ${#pkgs[@]} package(s)" runas_root apt-get install -y --no-install-recommends "${pkgs[@]}" || ok=false
            ;;
        pacman)
            if ! command -v pacman &>/dev/null; then return 1; fi
            spinner "Installing ${#pkgs[@]} package(s)" runas_root pacman --noconfirm --needed -S "${pkgs[@]}" || ok=false
            ;;
        *)
            return 1
            ;;
    esac

    if [[ "$ok" == "false" ]]; then
        fail "Package installation failed — see the Problem details above."
        warn "Manual resolution:"
        echo -e "      ${CYAN}sudo $cmd install -y --allowerasing ${pkgs[*]}${NC}"
        echo -e "      ${CYAN}sudo $cmd install -y --skip-broken ${pkgs[*]}${NC}"
        return 1
    fi
    return 0
}

# ----------------------------------------------------------------------------
#  pkg_install_erase — install while allowing the replacement of conflicting
#  packages. Only used for the RPM Fusion ffmpeg swap: the full `ffmpeg`
#  intentionally replaces Fedora's `ffmpeg-free` split libs (libavcodec-free,
#  libswresample-free…), which dnf only permits with --allowerasing. This is
#  the standard RPM Fusion install command, NOT a blind auto-erase.
# ----------------------------------------------------------------------------
pkg_install_erase() {
    local pkgs=("$@")
    local cmd
    cmd="$(pkg_cmd)"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} $cmd install -y --allowerasing ${pkgs[*]}"
        return 0
    fi

    if [[ "$cmd" == "dnf5" || "$cmd" == "dnf" ]]; then
        spinner "Installing ffmpeg (replaces ffmpeg-free)" runas_root "$cmd" install -y --allowerasing "${pkgs[@]}"
    else
        spinner "Installing ${#pkgs[@]} package(s)" runas_root "$cmd" install -y "${pkgs[@]}"
    fi
}

# ----------------------------------------------------------------------------
#  pkg_remove — uninstall a package (used for the "remove Firefox" step).
# ----------------------------------------------------------------------------
pkg_remove() {
    local pkg="$1"
    local cmd
    cmd="$(pkg_cmd)"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} $cmd remove -y $pkg"
        return 0
    fi

    case "$cmd" in
        dnf5|dnf) spinner "Removing: $pkg" runas_root "$cmd" remove -y "$pkg" ;;
        apt-get)  spinner "Removing: $pkg" runas_root apt-get remove -y "$pkg" ;;
        pacman)   spinner "Removing: $pkg" runas_root pacman --noconfirm -Rns "$pkg" ;;
        *)        return 1 ;;
    esac
}

# ----------------------------------------------------------------------------
#  pkg_update — refresh the package index (repositories).
# ----------------------------------------------------------------------------
pkg_update() {
    local cmd
    cmd="$(pkg_cmd)"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} $cmd update"
        return 0
    fi

    case "$cmd" in
        dnf5|dnf) spinner "Updating repositories" runas_root "$cmd" makecache ;;
        apt-get)  spinner "Updating repositories" runas_root apt-get update ;;
        pacman)   spinner "Updating repositories" runas_root pacman -Sy ;;
    esac
}

# ----------------------------------------------------------------------------
#  pkg_upgrade — apply all available system upgrades.
# ----------------------------------------------------------------------------
pkg_upgrade() {
    local cmd
    cmd="$(pkg_cmd)"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} $cmd upgrade -y"
        return 0
    fi

    case "$cmd" in
        dnf5|dnf) spinner "Upgrading system" runas_root "$cmd" upgrade -y ;;
        apt-get)  spinner "Upgrading system" runas_root apt-get upgrade -y; runas_root apt-get dist-upgrade -y ;;
        pacman)   spinner "Upgrading system" runas_root pacman -Su --noconfirm ;;
    esac
}

# ----------------------------------------------------------------------------
#  pkg_cleanup — remove orphaned/leftover dependencies.
# ----------------------------------------------------------------------------
pkg_cleanup() {
    local cmd
    cmd="$(pkg_cmd)"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} $cmd autoremove"
        return 0
    fi

    case "$cmd" in
        dnf5|dnf) spinner "Cleaning orphans" runas_root "$cmd" autoremove -y ;;
        apt-get)  spinner "Cleaning orphans" runas_root apt-get autoremove -y ;;
        pacman)   spinner "Cleaning orphans" runas_root pacman -Sc --noconfirm ;;
    esac
}

# ----------------------------------------------------------------------------
#  root_run — run a command as root, respecting --dry-run.
# ----------------------------------------------------------------------------
root_run() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} $*"
        return 0
    fi
    runas_root "$@"
}

# ----------------------------------------------------------------------------
#  run_as_user — run a command as the *target* user (not root), so user-level
#  installers (Ollama, uv, fnm, rustup, pnpm…) install into the right $HOME.
#  Respects --dry-run.
# ----------------------------------------------------------------------------
run_as_user() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} (as $TARGET_USER) $*"
        return 0
    fi
    # pipefail: installers are "curl | bash" pipelines — without it a failed
    # curl (e.g. 404) still exits 0 because bash reads an empty stdin.
    if [[ $EUID -eq 0 ]] && [[ "$TARGET_USER" != "root" ]]; then
        runuser -u "$TARGET_USER" -- bash -o pipefail -c "$*"
    else
        bash -o pipefail -c "$*"
    fi
}

# ----------------------------------------------------------------------------
#  pkg_run — run the native package manager as root, respecting --dry-run.
#  Usage:  pkg_run install -y <pkgs...>
# ----------------------------------------------------------------------------
pkg_run() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} $(pkg_cmd) $*"
        return 0
    fi
    runas_root "$(pkg_cmd)" "$@"
}

# ----------------------------------------------------------------------------
#  check_disk_space — warn if the free space on the target home is low.
#  Flatpak apps + codecs can need several GB; warn early so the user can
#  resize the disk / VM before the heavy stages run.
# ----------------------------------------------------------------------------
check_disk_space() {
    local min_mb="${1:-2048}"
    local avail_kb avail_mb
    avail_kb="$(df -k "$TARGET_HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
    if [[ -z "$avail_kb" ]]; then
        return 0
    fi
    avail_mb=$(( avail_kb / 1024 ))
    if (( avail_mb < min_mb )); then
        warn "Low disk space: only ${avail_mb} MB free on $TARGET_HOME (need ~${min_mb} MB)."
        warn "Resize the disk/VM or free space before running the heavy stages."
    fi
}

# ----------------------------------------------------------------------------
#  flatpak_native_equiv — map a Flatpak app ID to the distro package that
#  provides the same app. If that native package is already installed the
#  Flatpak is skipped, so the script never duplicates what the distro ships
#  (e.g. Debian's libreoffice / vlc).
# ----------------------------------------------------------------------------
flatpak_native_equiv() {
    case "$1" in
        org.libreoffice.LibreOffice)          echo "libreoffice" ;;
        org.videolan.VLC)                     echo "vlc" ;;
        org.telegram.desktop)                 echo "telegram-desktop" ;;
        com.spotify.Client)                   echo "spotify-client" ;;
        org.sqlitebrowser.sqlitebrowser)      echo "sqlitebrowser" ;;
        *) return 1 ;;
    esac
}

# ----------------------------------------------------------------------------
#  flatpak_install — install a Flathub app if not already present.
# ----------------------------------------------------------------------------
flatpak_install() {
    local app="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} flatpak install -y flathub $app"
        return 0
    fi

    if flatpak info "$app" &>/dev/null; then
        skip "$app"
        return 0
    fi

    # If the same app is already provided by a native package, don't install
    # a parallel Flatpak copy.
    local native
    if native="$(flatpak_native_equiv "$app")" && pkg_installed "$native"; then
        skip "$app (native package: $native)"
        return 0
    fi

    # Availability gate: verify the app ID resolves in Flathub *before*
    # installing, so a typo'd/renamed ID (e.g. Bottles) shows a clear warning
    # instead of a generic install failure.
    if command -v flatpak &>/dev/null && ! flatpak remote-info flathub "$app" &>/dev/null; then
        warn "Flatpak '$app' not found in Flathub — skipping (check the ID?)"
        return 0
    fi

    if spinner "Installing: $app" runas_root flatpak install -y flathub "$app"; then
        if grep -q "Creating new namespace failed" "${SPINNER_LAST_OUT:-}" 2>/dev/null; then
            warn "$app installed, but the sandbox is unavailable (bwrap blocked — container?)"
        else
            ok "Flatpak: $app"
        fi
    else
        fail "Flatpak: $app"
    fi
}

# ----------------------------------------------------------------------------
#  flatpak_remove — uninstall a Flathub app if it is present.
# ----------------------------------------------------------------------------
flatpak_remove() {
    local app="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} flatpak uninstall -y $app"
        return 0
    fi

    if ! flatpak info "$app" &>/dev/null; then
        skip "$app (not installed)"
        return 0
    fi

    if spinner "Removing: $app" runas_root flatpak uninstall -y "$app"; then
        ok "Flatpak removed: $app"
    else
        warn "Could not remove Flatpak: $app"
    fi
}

# ----------------------------------------------------------------------------
#  remove_path — delete a file/dir, respecting --dry-run.
#  Used by the revert stage to undo the setup's changes.
# ----------------------------------------------------------------------------
remove_path() {
    local path="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} rm -rf $path"
        return 0
    fi

    if [[ -e "$path" ]]; then
        runas_root rm -rf "$path" 2>/dev/null
        ok "Removed: ${path#"$TARGET_HOME"/}"
    else
        skip "Missing: ${path#"$TARGET_HOME"/}"
    fi
}

# ----------------------------------------------------------------------------
#  ensure_flatpak — make sure the flatpak tool + Flathub remote exist.
# ----------------------------------------------------------------------------
ensure_flatpak() {
    if ! command -v flatpak &>/dev/null; then
        info "Installing flatpak (system package)..."
        record_installed flatpak
        pkg_install flatpak
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
        return 0
    fi

    if ! flatpak remotes 2>/dev/null | grep -q flathub; then
        runas_root flatpak remote-add --if-not-exists flathub "https://flathub.org/repo/flathub.flatpakrepo"
        ok "Flathub remote added"
    else
        skip "Flathub remote"
    fi
}

# ----------------------------------------------------------------------------
#  record_installed — remember which packages THIS script actually installed
#  (as opposed to ones that were already present). Written to
#  $STATE_FILE.installed so --revert can uninstall exactly what the setup
#  added, never packages the user had before. Deduplicated and line-based.
# ----------------------------------------------------------------------------
record_installed() {
    local pkg
    for pkg in "$@"; do
        [[ -z "$pkg" ]] && continue
        if [[ ! -f "$STATE_FILE.installed" ]] || ! grep -qxF "$pkg" "$STATE_FILE.installed" 2>/dev/null; then
            echo "$pkg" >>"$STATE_FILE.installed"
        fi
    done
    state_fix_owner
}

# ----------------------------------------------------------------------------
#  read_installed — print the recorded package list (one per line).
# ----------------------------------------------------------------------------
read_installed() {
    [[ -f "$STATE_FILE.installed" ]] && cat "$STATE_FILE.installed" 2>/dev/null
    return 0
}

# ----------------------------------------------------------------------------
#  fix_config_owner — repair ownership of the dotfile dirs the setup manages.
#  When run via sudo the deployed configs (and pre-existing ones from an older
#  run) can end up owned by root, which breaks fish/kitty/ranger writing their
#  own state (e.g. .config/fish/fish_variables → "Permission denied"). Called
#  at the start of every run so a re-run self-heals without manual chown.
# ----------------------------------------------------------------------------
fix_config_owner() {
    if [[ $EUID -eq 0 ]] && [[ "$TARGET_USER" != "root" ]]; then
        local dir
        for dir in "$TARGET_HOME/.config/fish" \
                   "$TARGET_HOME/.config/kitty" \
                   "$TARGET_HOME/.config/ranger" \
                   "$TARGET_HOME/.config/environment.d"; do
            if [[ -d "$dir" ]]; then
                chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$dir" 2>/dev/null
            fi
        done
    fi
}

# ----------------------------------------------------------------------------
#  copy_config — deploy a dotfile from the repo into the target user's home.
# ----------------------------------------------------------------------------
copy_config() {
    local src="$1"
    local dst="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${BLUE}[DRY]${NC} cp $src -> $dst"
        return 0
    fi

    mkdir -p "$(dirname "$dst")"
    if cp "$src" "$dst"; then
        # When run via sudo (auto-elevation) the files land as root; hand them
        # back to the target user so their dotfiles stay writable (fish stores
        # fish_variables, kitty/ranger write caches, etc.).
        if [[ $EUID -eq 0 ]] && [[ "$TARGET_USER" != "root" ]]; then
            chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$(dirname "$dst")" 2>/dev/null
        fi
        ok "Config: ${dst#"$TARGET_HOME"/}"
    else
        fail "Config: $dst"
    fi
}
