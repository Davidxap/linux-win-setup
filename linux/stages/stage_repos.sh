#!/usr/bin/env bash
# ============================================================================
#  stage: repos — Enable the repositories the other stages rely on.
#
#  - Fedora : RPM Fusion (free + nonfree) for codecs/gaming + Docker CE repo
#  - Debian : attempt contrib/non-free component + Flathub
#  - Arch   : Flathub only (the AUR helper is a user choice)
#  - All    : Flathub remote for Flatpak apps
# ============================================================================

stage_repos() {
    section "Repositories" "Enable the package sources that the rest of the setup needs."
    local family cmd
    family="$(detect_family)"
    cmd="$(pkg_cmd)"

    case "$family" in
        fedora)
            # RPM Fusion (free + nonfree) provides codecs & Steam.
            if rpm -q rpmfusion-free-release rpmfusion-nonfree-release &>/dev/null; then
                skip "RPM Fusion (free + nonfree)"
            else
                info "Adding RPM Fusion (free + nonfree)"
                pkg_run install -y \
                    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
                    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
                ok "RPM Fusion configured"
            fi

            # Docker CE stable repository.
            if "${cmd}" repolist 2>/dev/null | grep -q docker-ce-stable; then
                skip "Docker CE repo"
            else
                info "Adding Docker CE repo"
                pkg_run config-manager addrepo --from-repofile="https://download.docker.com/linux/fedora/docker-ce.repo"
                ok "Docker CE repo configured"
            fi
            ;;

        debian)
            # Enable the components required by Steam/codecs. Debian uses
            # 'contrib non-free non-free-firmware'; Ubuntu uses 'multiverse'.
            local comps need
            if [[ "$(detect_distro)" == "ubuntu" ]]; then
                comps="multiverse"
            else
                comps="contrib non-free non-free-firmware"
            fi

            need=0
            local c
            for c in $comps; do
                # Match whole component names only: 'non-free' must not match
                # the substring inside 'non-free-firmware'. Only consider
                # Debian sources (deb.debian.org / security.debian.org) —
                # third-party repos (e.g. Docker) must never be modified.
                if grep -rqE "deb\.debian\.org|security\.debian\.org" \
                        /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
                    grep -rqE "(^|[[:space:]])$c([[:space:]]|\$)" \
                        /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null || need=1
                else
                    need=1
                fi
            done

            if (( need == 0 )); then
                skip "apt components ($comps)"
            else
                info "Enabling apt components: $comps"
                # deb822 sources (*.sources) use a 'Components:' field.
                # Only skip when *all* components are present — a single
                # substring match (e.g. non-free-firmware) is not enough.
                local f c all_present
                for f in /etc/apt/sources.list.d/*.sources; do
                    [[ -f "$f" ]] || continue
                    grep -qE "deb\.debian\.org|security\.debian\.org" "$f" || continue
                    all_present=1
                    for c in $comps; do
                        grep -qE "(^|[[:space:]])$c([[:space:]]|\$)" "$f" || all_present=0
                    done
                    (( all_present == 1 )) && continue
                    root_run sed -i -E "s/^(Components:[[:space:]]+)/\1$comps /" "$f"
                done
                # legacy sources.list / *.list append the components per line.
                # Only touch Debian repos — third-party *.list files (e.g.
                # Docker) must never get contrib/non-free components.
                for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
                    [[ -f "$f" ]] || continue
                    grep -qE "deb\.debian\.org|security\.debian\.org" "$f" || continue
                    all_present=1
                    for c in $comps; do
                        grep -qE "(^|[[:space:]])$c([[:space:]]|\$)" "$f" || all_present=0
                    done
                    (( all_present == 1 )) && continue
                    root_run sed -i -E "/^deb[[:space:]]/ s/[[:space:]]*\$/ $comps/" "$f"
                done
                pkg_run update
                ok "apt components enabled"
            fi

            # Steam on amd64 ships 32-bit libs; add the i386 foreign arch.
            if [[ "$(dpkg --print-architecture)" == "amd64" ]]; then
                if ! dpkg --print-foreign-architectures 2>/dev/null | grep -q '^i386$'; then
                    root_run dpkg --add-architecture i386
                    info "Added i386 architecture (required by Steam)"
                    pkg_run update
                fi
            fi

            # Docker CE stable repository (matches the Fedora stack).
            local codename
            codename="$(sed -n 's/^VERSION_CODENAME=//p' /etc/os-release | tr -d '"' | head -1)"
            if grep -rq "download.docker.com" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
                skip "Docker CE repo"
            else
                info "Adding Docker CE repo (${codename:-stable})"
                # curl/gpg may be missing on minimal cloud images (e.g. Debian) —
                # the repo key must be dearmored with gpg.
                root_run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl ca-certificates gnupg >/dev/null
                root_run sh -c "install -d -m 0755 /usr/share/keyrings && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg"
                root_run sh -c "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian/ ${codename:-bookworm} stable' > /etc/apt/sources.list.d/docker.list"
                pkg_run update
                ok "Docker CE repo configured"
            fi
            ;;

        arch)
            info "Arch: Flathub only (AUR helper, e.g. paru/yay, is your choice)"
            ;;
    esac

    ensure_flatpak
}