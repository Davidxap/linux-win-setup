#!/usr/bin/env bash
# ============================================================================
#  lib/ui.sh — Terminal UI helpers (colors, banners, progress, prompts).
#
#  Keeps every script in the repo with the same look & feel: colored output,
#  a real progress bar, a spinner for long operations, and simple prompts.
# ============================================================================

# Colors are only emitted when stdout is a terminal (nicer logs/CI output).
# shellcheck disable=SC2034
if [[ -t 1 ]]; then
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    BLUE=$'\033[0;34m'
    MAGENTA=$'\033[0;35m'
    CYAN=$'\033[0;36m'
    NC=$'\033[0m'
else
    BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; NC=''
fi

LOG_FILE="${LOG_FILE:-$HOME/.config/linux-win-setup.log}"
mkdir -p "$(dirname "$LOG_FILE")"

# ----------------------------------------------------------------------------
#  Message helpers (each one logs to $LOG_FILE as well).
# ----------------------------------------------------------------------------
log_msg() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
}

ok()   { echo -e "  ${GREEN}✓${NC} $*";              log_msg "[OK]   $*"; }
skip() { echo -e "  ${YELLOW}⊘${NC} $* (already installed)"; log_msg "[SKIP] $*"; }
fail() { echo -e "  ${RED}✗${NC} $*";                log_msg "[FAIL] $*"; }
info() { echo -e "  ${BLUE}ℹ${NC} $*";               log_msg "[INFO] $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $*";             log_msg "[WARN] $*"; }

# ----------------------------------------------------------------------------
#  banner — Big ASCII title block with a Catppuccin gradient.
#  The art lives in lib/banner.art (shared with setup.sh).
# ----------------------------------------------------------------------------
BANNER_ART="$(dirname "${BASH_SOURCE[0]}")/banner.art"

banner() {
    local grad=( "38;2;245;194;231" "38;2;203;166;247" "38;2;137;180;250" \
                 "38;2;137;220;235" "38;2;148;226;213" "38;2;166;227;161" )
    local b="" c="" r=""
    if [[ -t 1 ]]; then
        b=$'\033[1m'; r=$'\033[0m'
    fi
    local i=0 line
    while IFS= read -r line; do
        [ -n "$line" ] || { i=$((i + 1)); continue; }
        if [[ -t 1 ]]; then
            c=$'\033['"${grad[$((i % ${#grad[@]}))]}"'m'
        fi
        printf '    %s%s%s\n' "$b$c" "$line" "$r"
        i=$((i + 1))
    done <"$BANNER_ART"
    echo ""
    echo -e "  ${BOLD}$1${NC}"
    echo -e "  ${DIM}https://github.com/Davidxap/linux-win-setup${NC}"
    echo ""
}

# ----------------------------------------------------------------------------
#  section — Marks the beginning of a stage with a clean header.
# ----------------------------------------------------------------------------
section() {
    local name="$1"
    local desc="$2"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}◆ $name${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${YELLOW}$desc${NC}"
    log_msg "--- $name ---"
}

# ----------------------------------------------------------------------------
#  spinner — Runs a command while showing an animated loading indicator.
#  Output is captured to $SPINNER_LAST_OUT so callers can inspect it (e.g. to
#  detect bwrap warnings). On failure the last lines are replayed and the full
#  output is appended to the log. Without a TTY it just runs the command.
#  Usage:  spinner "label" command arg1 arg2 ...
# ----------------------------------------------------------------------------
SPINNER_LAST_OUT=""

spinner() {
    local label="$1"
    shift
    [[ -n "$SPINNER_LAST_OUT" && -f "$SPINNER_LAST_OUT" ]] && rm -f "$SPINNER_LAST_OUT"
    local pid i=0 out code
    # shellcheck disable=SC1003
    local spin=('|' '/' '-' '\')
    out="$(mktemp)"
    SPINNER_LAST_OUT="$out"
    if [[ ! -t 1 ]]; then
        "$@" >"$out" 2>&1
        code=$?
        cat "$out" >&2
    else
        # Print the label once; only the small spinner frame is redrawn in
        # place, so long dnf/flatpak batches don't flood the terminal.
        printf '  %s  ' "$label"
        "$@" >"$out" 2>&1 &
        pid=$!
        while kill -0 "$pid" 2>/dev/null; do
            printf '%s\b' "${spin[i]}"
            i=$(((i + 1) % 4))
            sleep 0.1
        done
        wait "$pid"
        code=$?
        printf '\b \n'
    fi
    if [[ $code -ne 0 ]]; then
        [[ -t 1 ]] && tail -n 15 "$out" >&2
        cat "$out" >>"$LOG_FILE"
    fi
    return $code
}

# ----------------------------------------------------------------------------
#  progress_bar — Draws a real terminal progress bar.
#  Usage:  progress_bar <done> <total> [status_text]
# ----------------------------------------------------------------------------
progress_bar() {
    local done="$1"
    local total="$2"
    local status="${3:-}"
    local width=30
    local pct=0
    local filled=0
    local bar=''

    if (( total > 0 )); then
        pct=$(( done * 100 / total ))
        filled=$(( done * width / total ))
    fi

    for (( i = 0; i < width; i++ )); do
        if (( i < filled )); then
            bar+='█'
        else
            bar+='░'
        fi
    done

    printf '\r  [%s] %3d%%  %s' "$bar" "$pct" "$status"
    if (( done == total && total > 0 )); then
        printf '\r  [%s] %3d%%  %s\n' "$bar" "$pct" "$status"
    fi
}

# ----------------------------------------------------------------------------
#  tty_input — asks whether a real interactive terminal is available.
#  Tries to open the controlling terminal; returns false in CI, in a pipe,
#  or inside containers where /dev/tty exists but cannot be opened.
# ----------------------------------------------------------------------------
tty_input() {
    local fd
    if { exec {fd}< /dev/tty; } 2>/dev/null; then
        exec {fd}<&-
        return 0
    fi
    return 1
}

# ----------------------------------------------------------------------------
#  flush_tty — discard any pending input on the controlling terminal so a
#  previous stage's output (or a stray key press during a spinner) can't leak
#  into the next read and cause bogus "Invalid option." prompts.
# ----------------------------------------------------------------------------
flush_tty() {
    local buf
    # < /dev/tty inside a while condition: on hosts without a controlling
    # terminal bash prints a redirection error — send it to /dev/null.
    if ! tty_input; then
        return 0
    fi
    while read -r -t 0 -n 1 buf </dev/tty 2>/dev/null; do :; done
    return 0
}

# ----------------------------------------------------------------------------
#  prompt_multi_choice — multi-select checklist.
#  Usage:  echo "$(prompt_multi_choice "message" "opt1" "opt2" ...)"
#  Accepts a comma list ("1,3"), "all"/"a" or "none"/"n".
#  Echoes selected indices space-separated. Non-interactive → none.
# ----------------------------------------------------------------------------
prompt_multi_choice() {
    local message="$1"
    shift
    local options=("$@")
    local i

    if [[ "${ASSUME_YES:-false}" == "true" ]] || ! tty_input; then
        echo ""
        return
    fi

    echo "" >&2
    echo "  $message" >&2
    echo -e "  ${DIM}(comma list like 1,3,5 | a = all | n = none)${NC}" >&2
    for (( i = 0; i < ${#options[@]}; i++ )); do
        echo -e "    ${CYAN}[$(( i + 1 ))]${NC} ${options[i]}" >&2
    done

    while true; do
        flush_tty
        read -r -p "  Select: " answer </dev/tty
        answer="$(echo "$answer" | tr -d ' ')"
        case "$answer" in
            a|all|A)  echo -e "  ${DIM}Selected: all${NC}" >&2; seq 1 "${#options[@]}"; return ;;
            n|none|0) echo -e "  ${DIM}Selected: none${NC}" >&2; echo ""; return ;;
        esac
        local picked=() valid=1
        IFS=',' read -r -a list <<<"$answer"
        for num in "${list[@]}"; do
            if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#options[@]} )); then
                picked+=("$num")
            else
                valid=0
            fi
        done
        if (( valid && ${#picked[@]} > 0 )); then
            local chosen=()
            for num in "${picked[@]}"; do chosen+=("${options[num - 1]}"); done
            echo -e "  ${DIM}Selected: ${chosen[*]}${NC}" >&2
            echo "${picked[*]}"
            return
        fi
        echo "  Invalid option." >&2
    done
}

# ----------------------------------------------------------------------------
#  prompt_confirm — Yes/No question.
#  Usage:  prompt_confirm "Question?" [default: y|n]
#  Returns 0 for yes, 1 for no.
# ----------------------------------------------------------------------------
prompt_confirm() {
    local question="$1"
    local default="${2:-}"
    local answer

    if [[ "${ASSUME_YES:-false}" == "true" ]]; then
        return 0
    fi
    if ! tty_input; then
        return 0
    fi

    case "$default" in
        y) question+=" [Y/n] " ;;
        n) question+=" [y/N] " ;;
        *) question+=" [y/n] " ;;
    esac

    while true; do
        flush_tty
        read -r -p "$question" answer </dev/tty
        case "${answer:-$default}" in
            y|Y|yes|YES) return 0 ;;
            n|N|no|NO)   return 1 ;;
        esac
        echo "  Please answer 'y' or 'n'."
    done
}

# ----------------------------------------------------------------------------
#  prompt_choice — Numbered list selection.
#  Usage:  echo "$(prompt_choice "message" "opt1" "opt2" ...)"
#  Accepts a single number, a comma list ("1,2,3"), "all"/"a" or "none"/"n".
#  Echoes the chosen indices space-separated (single choice → one number),
#  or "all"/"none" when the shortcut is used. Defaults to option 1 when
#  non-interactive.
# ----------------------------------------------------------------------------
prompt_choice() {
    local message="$1"
    shift
    local options=("$@")
    local answer i

    if [[ "${ASSUME_YES:-false}" == "true" ]] || ! tty_input; then
        echo 1
        return
    fi

    echo "" >&2
    echo "  $message" >&2
    echo -e "  ${DIM}(comma list like 1,2,3 | a = all | n = none)${NC}" >&2
    for (( i = 0; i < ${#options[@]}; i++ )); do
        echo -e "    ${CYAN}[$(( i + 1 ))]${NC} ${options[i]}" >&2
    done

    while true; do
        flush_tty
        read -r -p "  Select [1-${#options[@]}]: " answer </dev/tty
        answer="$(echo "$answer" | tr -d ' \t')"
        case "$answer" in
            a|all|both|A)
                echo -e "  ${DIM}Selected: all${NC}" >&2
                echo "all"
                return
                ;;
            n|none|s|skip|0)
                echo -e "  ${DIM}Selected: none${NC}" >&2
                echo "none"
                return
                ;;
        esac
        local picked=() valid=1
        IFS=',' read -r -a list <<<"$answer"
        for num in "${list[@]}"; do
            if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#options[@]} )); then
                picked+=("$num")
            else
                valid=0
            fi
        done
        if (( valid && ${#picked[@]} > 0 )); then
            local chosen=() n
            for n in "${picked[@]}"; do chosen+=("${options[n - 1]}"); done
            echo -e "  ${DIM}Selected: ${chosen[*]}${NC}" >&2
            echo "${picked[*]}"
            return
        fi
        echo "  Invalid option." >&2
    done
}
