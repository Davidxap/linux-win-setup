# ============================================================================
#  config.fish — Daily-driver fish shell configuration.
#
#  Highlights (all optional, each tool is detected before use):
#    - Auto-suggestions in grey           → accept with Right arrow
#    - Syntax highlighting: GREEN command = installed, RED = not installed
#    - zoxide (z / zi) for smart cd · fzf (Ctrl+R/Ctrl+T/Alt+C)
#    - Modern aliases: ls=eza(cwith icons), cat=bat, ff=fd, rgf=rg --files
#    - command-not-found handler that suggests the package to install
#    - User runtimes on PATH: uv, fnm, pnpm, cargo, ~/.local/bin, opencode
# ============================================================================

# No automatic greeting on launch. `fastfetch` stays installed and can be run
# manually whenever you want the system summary (logo + info).
if status is-interactive
    set -g fish_greeting
end

# -------------------- Autocomplete / suggestions -------------------------
set -g fish_autosuggestion_enabled 1
set -g fish_enable_key_bindings 1

# -------------------- Missing-command handler ----------------------------
# fish already paints unknown commands in red while you type; if you run one
# anyway, this handler suggests the distro package that provides it.
function __fish_command_not_found_handler --on-event fish_command_not_found
    set -l cmd $argv[1]
    set -l red (set_color e78284 --bold)
    set -l green (set_color a6d189 --bold)
    set -l nc (set_color normal)
    echo
    if test -x /usr/bin/dnf
        set pkg (dnf -q provides "*/bin/$cmd" 2>/dev/null | string match -r '^([a-zA-Z0-9_.+-]+)' | head -1)
        if test -n "$pkg"
            echo "  $red✗$nc '$cmd' is not installed. Try:  $green sudo dnf install $pkg $nc"
            return
        end
    end
    if test -x /usr/bin/apt-get
        if command -q apt-file
            set pkg (apt-file search --regexp "/$cmd\$" 2>/dev/null | string match -r '^([a-zA-Z0-9_.+-]+)' | head -1)
            if test -n "$pkg"
                echo "  $red✗$nc '$cmd' is not installed. Try:  $green sudo apt install $pkg $nc"
                return
            end
        else
            echo "  $red✗$nc '$cmd' unknown (install 'apt-file' to search: sudo apt install apt-file && sudo apt-file update)"
            return
        end
    end
    echo "  $red✗$nc '$cmd' does not exist."
end

# -------------------- User runtimes -------------------------
# fnm (Node version manager, user-local install)
if test -x "$HOME/.local/share/fnm/fnm"
    fish_add_path "$HOME/.local/share/fnm"
    fnm env --shell fish | source
end

# opencode (installed by the setup in ~/.opencode/bin)
fish_add_path "$HOME/.opencode/bin"

# pnpm (portable install path)
set -gx PNPM_HOME "$HOME/.local/share/pnpm"
if not string match -q -- "$PNPM_HOME/bin" $PATH
    set -gx PATH "$PNPM_HOME/bin" $PATH
end

# cargo (Rust)
if test -x "$HOME/.cargo/bin/cargo"
    fish_add_path "$HOME/.cargo/bin"
end

# local user binaries
fish_add_path "$HOME/.local/bin"

# -------------------- Smart navigation -----------------------------------
# zoxide: 'z <dir>' jumps to frequent/recent dirs, 'zi' is interactive
if command -q zoxide
    zoxide init fish | source
end

# fzf: Ctrl+T files / Ctrl+R history / Alt+C cd
if command -q fzf
    fzf --fish | source
    set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border --cycle'
end

# Modern aliases with icons (only when the new tools are present)
if command -q eza
    alias ls 'eza --icons --group-directories-first'
    alias l  'eza -lg --icons --group-directories-first --git'
    alias ll 'eza -l  --icons --group-directories-first --git'
    alias la 'eza -la --icons --group-directories-first --git'
    alias lt 'eza -l --tree --icons --level=2'
else
    alias ls 'ls --color=auto --group-directories-first'
    alias l  'ls -l'
    alias ll 'ls -l'
    alias la 'ls -la'
    alias lt 'ls -R'
end

if command -q bat
    alias cat 'bat'
    alias catp 'bat --plain'
end
if command -q fd
    alias ff 'fd'
else if command -q fdfind
    alias ff 'fdfind'
end
if command -q rg
    alias rgf 'rg --files'
end