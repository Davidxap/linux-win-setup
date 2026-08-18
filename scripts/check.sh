#!/usr/bin/env bash
# shellcheck disable=SC2086,SC2016
# ============================================================================
#  scripts/check.sh — Static checks for the whole repo (Linux + Windows parts).
#
#  Runs, when possible, on every source file:
#   1. bash -n           syntax check for .sh/.bash
#   2. ShellCheck        lint (via ShellCheck or docker koalaman/shellcheck)
#   3. PowerShell        parse of .ps1 (via pwsh or docker mcr powershell:lts)
#   4. Secret scan       flags obvious API keys / tokens / private keys
# ============================================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

fail=0

echo "== bash -n =="
while IFS= read -r f; do
    [ -n "$f" ] || continue
    bash -n "$f" || { echo "  ✗ syntax: $f"; fail=1; }
done < <(find setup.sh linux wsl lib scripts -name '*.sh' -o -name '*.bash' | sort)
echo "  ok"

echo "== ShellCheck =="
sh_files="$(find setup.sh linux wsl lib scripts -name '*.sh' | sort)"
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x -e SC1090,SC1091,SC2148,SC2154 $sh_files || fail=1
elif command -v docker >/dev/null 2>&1; then
    args=""
    while IFS= read -r f; do
        [ -n "$f" ] && args="$args /work/$f"
    done <<< "$sh_files"
    docker run --rm -v "$PWD:/work:ro" koalaman/shellcheck:stable \
        -x -e SC1090,SC1091,SC2148,SC2154 $args || fail=1
else
    echo "  (shellcheck not available — skipped)"
fi

echo "== PowerShell (parse) =="
ps1_files="$(find windows -name '*.ps1' | sort)"
pwsh_parse='$f=$env:P2;$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($f,[ref]$null,[ref]$e);if($e){$e|%{ Write-Error "PS1: $($_.Message)" };exit 1};Write-Host "  ok: $f"'
if command -v pwsh >/dev/null 2>&1; then
    for p in $ps1_files; do
        P2="$p" pwsh -NoProfile -Command "$pwsh_parse" || fail=1
    done
elif command -v docker >/dev/null 2>&1; then
    for p in $ps1_files; do
        docker run --rm -e P2="/work/$p" -v "$PWD:/work:ro" \
            mcr.microsoft.com/powershell:lts pwsh -NoProfile -Command "$pwsh_parse" || fail=1
    done
else
    echo "  (pwsh not available — skipped)"
fi

echo "== Secret / personal-data scan =="
pattern='(AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|xox[baprs]-|[0-9a-f]{64})'
hits="$(grep -rInE "$pattern" --exclude-dir=.git --exclude-dir=.venv . 2>/dev/null)"
if [ -n "$hits" ]; then
    echo "$hits"
    fail=1
else
    echo "  clean"
fi

echo ""
if [ "$fail" = 0 ]; then
    echo "✓ all checks passed."
else
    echo "✗ some checks failed."
fi
exit "$fail"