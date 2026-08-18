#!/usr/bin/env bash
# ============================================================================
#  lib/stages.sh — Stage registry, interactive selection, resume & state.
#
#  The Linux setup is split into numbered stages so users can run only what
#  they want ("install by stages") or resume from where a run failed.
# ============================================================================

STATE_FILE="${STATE_FILE:-$TARGET_HOME/.config/linux-win-setup-state}"
DRY_RUN="${DRY_RUN:-false}"
ASSUME_YES="${ASSUME_YES:-false}"

# Per-stage summaries shown in the pre-run confirmation (key → description).
# Use -g: stages.sh is sourced from inside the import() function, so a plain
# `declare -A` would create a function-local array and vanish on return.
declare -g -A STAGE_SUMMARY

# Ordered stage registry. Pair: <key>:<menu description>.
# Every key must have a matching `stage_<key>` function in linux/stages/.
STAGE_REGISTRY=(
    "repos:Add repositories (RPM Fusion / Flathub / Docker)"
    "update:System update (packages + flatpaks)"
    "packages:Base packages (CLI tools, codecs, fonts)"
    "apps:Flatpak desktop applications"
    "terminal:Terminal (kitty + fish / zsh+starship+tmux) — explains and asks your preference"
    "browser:Browser — choose any or all (Zen / Chrome / Brave)"
    "gaming:Gaming — GPU picker (AMD / NVIDIA / Intel) + GameMode + sysctl"
    "docker:Docker — native engine OR Docker Desktop (you choose)"
    "extra:Optional extras (dev tools, AI agents, editors, password managers, VMs…)"
    "cleanup:Final cleanup (orphans + unused flatpaks)"
)

readonly STAGE_COUNT="${#STAGE_REGISTRY[@]}"

# Short "what this stage installs/changes" summary, used by the pre-run plan
# confirmation so the user always knows what is about to happen.
STAGE_SUMMARY[repos]="Add RPM Fusion, Flathub and Docker repositories"
STAGE_SUMMARY[update]="Full system upgrade (dnf/flatpak) + refresh"
STAGE_SUMMARY[packages]="Base CLI tools, codecs, fonts + git/gh/neovim"
STAGE_SUMMARY[apps]="Flatpak desktop apps (Obsidian, Zen, VLC, Spotify…)"
STAGE_SUMMARY[terminal]="kitty + fish OR zsh+starship+tmux, as your default"
STAGE_SUMMARY[browser]="Install any or all browsers (Zen/Chrome/Brave)"
STAGE_SUMMARY[gaming]="GPU drivers, Steam, GameMode, MangoHud, GameScope"
STAGE_SUMMARY[docker]="Docker — native engine OR Docker Desktop (you choose)"
STAGE_SUMMARY[extra]="Optional tools: AI agents, editors, API clients, password managers, VMs…"
STAGE_SUMMARY[cleanup]="Remove orphaned packages and unused Flatpaks"
STAGE_SUMMARY[revert]="Uninstall everything the setup installed/configured"
STAGE_SUMMARY[revert:repos]="Remove RPM Fusion / Docker CE / Flathub"
STAGE_SUMMARY[revert:packages]="Uninstall the system packages the setup installed"
STAGE_SUMMARY[revert:apps]="Uninstall the Flatpak apps"
STAGE_SUMMARY[revert:terminal]="Remove fish/kitty/ranger configs + restore login shell"
STAGE_SUMMARY[revert:browser]="Remove the installed browser (Firefox)"
STAGE_SUMMARY[revert:gaming]="Remove gaming tuning (GameMode / sysctl / env)"
STAGE_SUMMARY[revert:docker]="Remove docker group + socket"
STAGE_SUMMARY[revert:extra]="Remove Ollama, uv, cargo, fnm, pnpm…"

stage_key()   { echo "${1%%:*}"; }
stage_label() { echo "${1#*:}"; }

# ----------------------------------------------------------------------------
#  read_manifest — print package names from a manifest file.
#  Blank lines and '#' comments are ignored; a line can carry several pkgs.
# ----------------------------------------------------------------------------
read_manifest() {
    local file="$1"
    [[ -f "$file" ]] || { warn "Manifest not found: $file"; return; }
    while IFS= read -r line; do
        line="${line%%#*}"
        [[ -z "$line" ]] && continue
        # shellcheck disable=SC2086
        echo $line
    done <"$file"
}

# ----------------------------------------------------------------------------
#  revert_area_key — map a menu/CLI number to the revert function that undoes
#  that stage. Stages with nothing to undo (update/packages/cleanup) return "".
# ----------------------------------------------------------------------------
revert_area_key() {
    local num="$1"
    case "$num" in
        1) echo "repos" ;;
        3) echo "packages" ;;
        4) echo "apps" ;;
        5) echo "terminal" ;;
        6) echo "browser" ;;
        7) echo "gaming" ;;
        8) echo "docker" ;;
        9) echo "extra" ;;
        *) echo "" ;;
    esac
}

# ----------------------------------------------------------------------------
#  Run a single stage via dispatch (safe guard for unknown keys).
#  Errexit is disabled for the duration so a failing stage never kills the
#  whole run — the caller (run_plan) decides what to do with the exit code.
# ----------------------------------------------------------------------------
run_stage() {
    local key="$1"
    local code=0

    case "$key" in
        repos | update | packages | apps | terminal | browser | gaming | docker | extra | cleanup | revert)
            set +e
            "stage_$key"
            code=$?
            set -e
            ;;
        revert:repos | revert:packages | revert:apps | revert:terminal | revert:browser | \
        revert:gaming | revert:docker | revert:extra)
            set +e
            "revert_${key#revert:}"
            code=$?
            set -e
            ;;
        *)
            fail "Unknown stage: $key"
            return 1
            ;;
    esac

    if [[ "$DRY_RUN" != "true" ]] && [[ ! -d /run/systemd/system ]]; then
        return $code
    fi
    if [[ "$DRY_RUN" != "true" ]]; then
        if [[ "$key" == "revert" || "$key" == revert:* ]]; then
            : # revert is not persisted in the resume state
        elif (( code == 0 )); then
            mark_done "$key"
        else
            mark_failed "$key"
        fi
    fi
    return $code
}

# ----------------------------------------------------------------------------
#  State file helpers — persists completed stages so a re-run can resume.
# ----------------------------------------------------------------------------
mark_done()   { echo "$1" >>"$STATE_FILE.done"; state_fix_owner; }
mark_failed() { echo "$1" >>"$STATE_FILE.failed"; state_fix_owner; }
is_done()     { grep -qx "$1" "$STATE_FILE.done" 2>/dev/null; }
state_reset() { rm -f "$STATE_FILE.done" "$STATE_FILE.failed"; state_fix_owner; }

# Keep the state files owned by the target user (they live in $TARGET_HOME and
# the script may run as root after auto-elevation).
state_fix_owner() {
    if [[ $EUID -eq 0 ]] && [[ "$TARGET_USER" != "root" ]]; then
        chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$(dirname "$STATE_FILE")" 2>/dev/null
    fi
}

# ----------------------------------------------------------------------------
#  resolve_selection — turn a user/CLI selection into an ordered key list.
#  Accepts: "all" | "resume" | "none" | "1,3,5"
# ----------------------------------------------------------------------------
resolve_selection() {
    local selection="${1:-all}"
    local keys=()
    local num

    case "$selection" in
        revert|r)
            keys+=("revert")
            ;;
        all|a|"" )
            for row in "${STAGE_REGISTRY[@]}"; do keys+=("$(stage_key "$row")"); done
            ;;
        resume)
            if [[ ! -f "$STATE_FILE.done" ]]; then
                warn "No previous run state — running all stages." >&2
                for row in "${STAGE_REGISTRY[@]}"; do keys+=("$(stage_key "$row")"); done
            else
                for row in "${STAGE_REGISTRY[@]}"; do
                    key="$(stage_key "$row")"
                    is_done "$key" || keys+=("$key")
                done
                echo -e "  ${BLUE}ℹ${NC} Resume — remaining: ${keys[*]:-(all done)}" >&2
            fi
            ;;
        none)
            return 0
            ;;
        *)
            local revert_mode=false
            [[ "$selection" =~ ^r[0-9,] ]] && revert_mode=true
            IFS=',' read -r -a list <<<"$selection"
            for num in "${list[@]}"; do
                num="$(echo "$num" | tr -d ' ')"
                # "r<num>" means "revert stage <num>" (undo that area only).
                # Once the selection starts with 'r', every number is a revert.
                if [[ "$revert_mode" == "true" ]]; then
                    local area
                    area="$(revert_area_key "${num#r}")"
                    if [[ -n "$area" ]]; then
                        keys+=("revert:$area")
                    else
                        warn "Stage ${num#r} has nothing to revert (1/3/4/5/6/7/8/9 only)"
                    fi
                elif [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= STAGE_COUNT )); then
                    keys+=("$(stage_key "${STAGE_REGISTRY[$((num - 1))]}")")
                else
                    warn "Ignoring invalid stage number: '$num'"
                fi
            done
            ;;
    esac

    echo "${keys[*]}"
}

# ----------------------------------------------------------------------------
#  show_menu — interactive selection (used when running without args).
#  UI goes to stderr so `$(show_menu)` captures only the user's answer.
# ----------------------------------------------------------------------------
show_menu() {
    local n=0
    echo "" >&2
    echo -e "  ${BOLD}Which stages do you want to run?${NC}" >&2
    for row in "${STAGE_REGISTRY[@]}"; do
        n=$((n + 1))
        printf "    ${CYAN}%2d.${NC} %s\n" "$n" "$(stage_label "$row")" >&2
    done
    echo -e "     ${CYAN} a ${NC} All stages (recommended first run)" >&2
    echo "" >&2
    echo -e "  ${BOLD}Uninstall (revert):${NC}" >&2
    echo -e "     ${CYAN} r ${NC} Revert everything (undo the whole setup)" >&2
    echo -e "     ${CYAN}r#${NC} Revert one area by number (e.g. r4 = remove Flatpak apps)" >&2
    echo "" >&2

    local answer
    read -r -p "  Selection (e.g. 1,3,5 | a | r | r4,9): " answer
    echo "" >&2
    echo "$answer"
}

# ----------------------------------------------------------------------------
#  run_plan — execute a list of stage keys in order.
#  Shows each stage with its summary and asks for confirmation (unless
#  --yes / non-interactive / --dry-run). Every stage runs even if an earlier
#  one failed; a final report lists what passed and what failed.
# ----------------------------------------------------------------------------
run_plan() {
    local plan="$1"
    [[ -z "$plan" ]] && { info "Nothing to run."; return 0; }

    # Repair ownership of previously-deployed dotfiles (may be root after an
    # earlier sudo run). Runs before anything else so configs are writable.
    fix_config_owner

    check_disk_space 2048

    echo -e "  ${BOLD}Plan${NC} — ${CYAN}$(echo "$plan" | wc -w)${NC} stage(s):"
    local key
    for key in $plan; do
        printf "    ${CYAN}•${NC} ${BOLD}%s${NC} — %s\n" "$key" "${STAGE_SUMMARY[$key]:-}"
    done
    echo ""

    if [[ "$ASSUME_YES" != "true" ]] && [[ -z "${SKIP_CONFIRM:-}" ]] && tty_input; then
        if ! prompt_confirm "Proceed with the plan above?" n; then
            info "Aborted by user."
            return 1
        fi
        echo ""
    fi

    local done_keys=() failed_keys=()
    local total_stages plan_keys=()
    read -r -a plan_keys <<< "$plan"
    total_stages=${#plan_keys[@]}
    local idx=0
    for key in $plan; do
        idx=$((idx + 1))
        echo ""
        progress_bar $((idx - 1)) "$total_stages" "STEP $idx/$total_stages — $key"
        echo ""
        if run_stage "$key"; then
            done_keys+=("$key")
        else
            failed_keys+=("$key")
        fi
        progress_bar "$idx" "$total_stages" "STEP $idx/$total_stages — $key done"
        echo ""
    done

    echo ""
    progress_bar "$total_stages" "$total_stages" "all stages done"
    echo ""
    echo -e "  ${BOLD}── Report ──${NC}"
    if (( ${#done_keys[@]} > 0 )); then
        echo -e "  ${GREEN}Passed (${#done_keys[@]}):${NC}"
        for key in "${done_keys[@]}"; do printf "    ${GREEN}✓${NC} %s\n" "$key"; done
    fi
    if (( ${#failed_keys[@]} > 0 )); then
        echo -e "  ${RED}Failed (${#failed_keys[@]}):${NC}"
        for key in "${failed_keys[@]}"; do printf "    ${RED}✗${NC} %s\n" "$key"; done
        echo -e "  ${YELLOW}Details → $LOG_FILE${NC}"
        return 1
    fi
    ok "All stages passed."
    return 0
}