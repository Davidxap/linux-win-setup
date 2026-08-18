# 🚀 linux-win-setup

> **Set up a fresh Linux or Windows 11 machine with one command** — the
> terminal, apps, gaming tuning, Docker and dev tools you actually use, without
> re-picking packages by memory after every reinstall.

`linux-win-setup` is an open-source setup script that automates the boring part
of any fresh install: it asks what you want, installs it consistently (one
browser, one terminal, one file manager — no duplicates), and can remove
everything again with a single revert. It works on **Fedora, Debian/Ubuntu and
Arch**, plus **Windows 11 (winget)** and **WSL**.

| | Linux (Fedora / Debian / Arch) | Windows 11 (winget) | WSL |
|---|---|---|---|
| **Shell/Terminal** | kitty + fish or zsh+starship+tmux (ask-first) | PowerShell + WSL option | fish |
| **Browser** | Zen/Chrome/Brave/Helios (any or all — multi-select) | Zen/Chrome/Brave/**Firefox** (any or all) | — |
| **Apps** | Flatpak (sandboxed apps) | winget + PDF & Doc tools | — |
| **Gaming** | GameMode + AMD tuning + sysctl | Game DVR off + High power | — |
| **Dev** | Docker — native engine **or** Docker Desktop (you choose) | Docker Desktop | CLI tools |

---

## ✅ Tested on

| Platform | Status |
|---|---|
| **Fedora 44 — GNOME** | ✔ tested |
| **Fedora 44 — KDE Plasma** | ✔ tested |
| **Debian 12 — GNOME** | ✔ tested |
| **Windows 11** | 🚧 planned — not yet verified. GPU drivers, tweaks and winget
  packages are adapted for Windows, but the run-through is still pending. |

The same script is the source of truth for all four rows above; Linux
(Fedora/Debian/Arch) shares one codebase with family-specific manifests, and
Windows runs its own PowerShell equivalent.

> **GPU drivers differ per OS.** On Linux the setup tunes the open-source
> stack (amdgpu/Mesa on AMD, proprietary drivers are a separate manual step on
> NVIDIA). On Windows 11 drivers come from the vendor (NVIDIA/AMD/Intel) —
> the Windows script detects your GPU and installs the matching vendor
> driver/app, because a Linux driver won't work there.

---

## 📋 Why this project exists

Reinstalling an operating system should not be an afternoon of archaeology.
You know the drill: after every format you sit there re-adding the same
programs, re-applying the same tweaks, and trying to remember that *one* sysctl
setting that stopped the GPU from stuttering last time.

This repo takes that whole mental list and turns it into a script. It is built
for the two situations where this pain shows up most:

- **You just formatted (or bought) a machine** and want it usable again
  without a shopping list of packages in your head.
- **You are migrating from Windows to Linux** (or reinstalling Windows 11)
  and want the same kind of one-shot setup experience you'd hope for, minus the
  guesswork about which app does what.

It is **not** an exact clone of your old machine — nobody can restore that —
but it gives you something arguably more useful: a clean, opinionated,
*working* setup you can stand on, install by install, decision by decision.
Everything is interactive and explained, so you understand what each step does
instead of trusting a black box.

**What it does:**

- Installs your base tools (codecs, fonts, editors, CLI replacements like
  `eza`, `bat`, `zoxide`, `fzf`).
- Sets up a terminal you'll actually enjoy: **kitty + fish** or
  **zsh + starship + tmux** — you choose.
- Adds Flatpak desktop apps (sandboxed, auto-updated).
- Tunes gaming on Linux: GameMode, AMD GPU power tweaks, sysctl, Wayland
  environment variables.
- Installs Docker (native engine or Docker Desktop) and optional dev/AI extras
  (Ollama, opencode, uv, rustup, virtual machines…).
- **Adds PDF & Doc tools (PDFedit, qpdf, Foxit, PDF-Shuffler) on Windows**
  and Linux Flatpak.
- Always asks before touching anything, and never installs the same app twice.

**What it does NOT do:**

- It is **not a distro** — it runs on top of your existing Fedora/Debian/Arch.
- It is **not a live dotfile syncer** — it deploys configs once, doesn't follow
  them around or fight you when you edit them.
- It is **not a one-way street** — everything it installs can be removed with
  `./setup.sh --revert`, which uninstalls exactly the packages/apps the setup
  itself added (recorded at install time) and leaves anything you already had
  untouched.

All the tuning was born from real use on AMD GPUs (KDE Wayland, X11 also
works) and kept **modular** so it adapts to other distros and other hardware.

---

## ⚡ Quick start

### Linux (Fedora / Debian / Ubuntu / Arch)

```bash
git clone https://github.com/Davidxap/linux-win-setup.git
cd linux-win-setup
chmod +x setup.sh
./setup.sh --dry-run --all      # preview the plan first (zero changes)
sudo ./setup.sh --all           # run everything (asks y/N confirmation)
```

> First time? Start with `--dry-run --all` to see exactly what each stage
> installs, then confirm the real run.

#### Updating an existing clone

The public repo keeps a **single root commit** (squashed) so the tree is easy
to audit — that means a plain `git pull` can fail with
`divergent branches` after an update. Fix it with:

```bash
cd linux-win-setup
git fetch origin
git reset --hard origin/main
```

or simply re-clone into a fresh folder. Re-running the setup is safe: every
stage is idempotent, and `--revert` removes exactly what the setup added.

### Windows 11

Requires **winget** (comes preinstalled). No git needed — the one-liner below
downloads the ZIP and runs the script directly.

**PowerShell** (open a fresh window, paste this one line):

```powershell
irm https://github.com/Davidxap/linux-win-setup/archive/refs/heads/main.zip -OutFile $env:TEMP\lws.zip; Expand-Archive $env:TEMP\lws.zip $env:TEMP\lws -Force; & "$env:TEMP\lws\linux-win-setup-main\windows\setup-windows.cmd"
```

**CMD** (open a fresh window):

```bat
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://github.com/Davidxap/linux-win-setup/archive/refs/heads/main.zip -OutFile $env:TEMP\lws.zip; Expand-Archive $env:TEMP\lws.zip $env:TEMP\lws -Force; & \"$env:TEMP\lws\linux-win-setup-main\windows\setup-windows.cmd\""
```

`windows\setup-windows.cmd` runs `setup-windows.ps1` with `-ExecutionPolicy
Bypass` and keeps the window open so you can read the output — even on error.

**No terminal required** — you can also just open the file:

1. Extract the ZIP (or clone the repo) somewhere easy to find.
2. Open `windows\setup-windows.cmd` with a **double-click** (or right-click →
   *Run with PowerShell* on `windows\setup-windows.ps1`).

The script starts with a small menu: `[1] Full setup` · `[2] Revert`
(uninstall what it added) · `[0] Quit`. You can also run the script directly:

```powershell
powershell -ExecutionPolicy Bypass -File windows\setup-windows.ps1
```

> **Have git?** The clone-based flow also works (the repo keeps a single
> squashed root commit, so use the exact commands below — a plain `git pull`
> will fail with `divergent branches`):

```powershell
Remove-Item -Recurse -Force $env:USERPROFILE\linux-win-setup -ErrorAction SilentlyContinue
cd $env:USERPROFILE
git clone https://github.com/Davidxap/linux-win-setup.git
cd linux-win-setup
windows\setup-windows.cmd
```

#### Updating an existing clone (Windows)

The public repo keeps a **single root commit** (squashed), so a `git pull` can
fail with `divergent branches`. Update with:

```powershell
cd linux-win-setup
git fetch origin
git reset --hard origin/main
```

or just re-clone into a fresh folder (delete it first, as shown above).

#### Uninstall (revert) on Windows

The Windows script mirrors the Linux `--revert`: it removes only what the
setup can install and restores the tweaks, always asking first.

**Easiest way:** run the script and pick **`[2] Revert`** from the start menu
(see above). No flags needed.

**With the flag** (goes straight to revert mode, no menu):

```powershell
powershell -ExecutionPolicy Bypass -File windows\setup-windows.ps1 -Revert
```

It asks which app groups to uninstall (Browsers, Media, Dev tools, **PDF & Doc tools**, Gaming, ...),
then removes each package with a **multi-method uninstaller**: `winget` first, then **MSIX / Microsoft
Store packages** (Brave, Discord, Spotify, …), then the app's own registry uninstaller (MSI / vendor
installer), then leftover-folder cleanup — so it works no matter how the app was originally installed,
even as a Store app. **Git is not in the revert list** (it stays installed). Apps that are not
installed at all are simply skipped, not counted as removed. At the end it prints a full summary of
what was removed, what failed, and what was skipped, and restores the gaming tweaks (Game DVR +
Balanced power plan). Add `-DryRun` to preview:
`powershell -ExecutionPolicy Bypass -File windows\setup-windows.ps1 -Revert -DryRun`

**Note:** The setup now includes **PDF & Doc tools** (PDFedit, qpdf, Foxit Reader,
PDF-Shuffler) as an optional category, and the **Gaming** category includes
Battle.net as the Blizzard launcher only (Warcraft III and World of Warcraft are
not forced install options). All options are optional — nothing is installed
without your explicit selection.

### WSL (Debian/Ubuntu inside Windows)

```bash
bash wsl/setup-wsl.sh          # fish + friendly CLI tools
bash wsl/setup-wsl.sh --all    # + extra tools (git, gh, python...)
```

---

## 🧭 Interactive by design

The script never touches your system silently. Every run follows the same
flow: **detect → pick → review → confirm → execute**. This section shows the
whole journey, step by step.

### 1. The banner

Every entry point prints the `LINUX-WIN-SETUP` ASCII logo in a bold Catppuccin
gradient (six colors: pink → mauve → blue → teal → green), then the platform
detection. The art lives in one shared file (`lib/banner.art`), so `setup.sh`
and `lib/ui.sh` always render the same logo:

```
    _     ___ _   _ _   ___  __  __        _____ _   _      ____  _____ _____ _   _ ____
   | |   |_ _| \ | | | | \ \/ /  \ \      / /_ _| \ | |    / ___|| ____|_   _| | | |  _ \
   | |    | ||  \| | | | |\  /____\ \ /\ / / | ||  \| |____\___ \|  _|   | | | | | | |_) |
   | |___ | || |\  | |_| |/  \_____\ V  V /  | || |\  |_____|__) | |___  | | | |_| |  __/
   |_____|___|_| \_|\___//_/\_\     \_/\_/  |___|_| \_|    |____/|_____|_|  \___/|_|

  Linux Setup — multi-distro
  https://github.com/Davidxap/linux-win-setup
```

> Colors are only emitted when stdout is a real terminal. Piped into a file or
> CI, the banner falls back to plain text so logs stay clean.

### 2. Stage menu

With no flags you get the interactive picker — type a list, a range or `a`:

```
  Which stages do you want to run?
     1. Add repositories (RPM Fusion / Flathub / Docker)
     2. System update (packages + flatpaks)
     3. Base packages (CLI tools, codecs, fonts)
     4. Flatpak desktop applications
     5. Terminal (kitty + fish / zsh+starship+tmux) — explains and asks your preference
     6. Browser — choose any or all: Zen / Chrome / Brave (multi-select)
     7. Gaming — GPU picker (AMD / NVIDIA / Intel) + GameMode + sysctl
     8. Docker — native engine or Docker Desktop (you choose)
     9. Optional extras (Ollama, opencode, uv, fnm+pnpm, rustup…)
    10. Final cleanup (orphans + unused flatpaks)
      a  All stages (recommended first run)

  Uninstall (revert):
     r  Revert everything (undo the whole setup)
     r# Revert one area by number (e.g. r4 = remove Flatpak apps)

  Selection (e.g. 1,3,5 | a | r | r4,9): 1,3,5
```

The same selection is available as flags (great for scripts and CI):

| Flag | Equivalent |
|---|---|
| `--all` | `a` |
| `--stages 1,3,5` | `1,3,5` |
| `--minimal` | `5,6` (terminal + browser) |
| `--resume` | re-run only the stages not yet completed |
| `--revert` | `r` (uninstall everything) |
| `--stages r4` | `r4` (revert just that area) |

Areas that have a revert counterpart: `r1` repos, `r3` packages, `r4` apps,
`r5` terminal, `r6` browser, `r7` gaming, `r8` docker, `r9` extras. Stages
2/10 (update, cleanup) only refresh the system, so they have nothing to undo.

`r3` (packages) uninstalls **exactly what the setup installed**, never the
packages you already had: during installation the script records every package
it installs (in `~/.config/linux-win-setup-state.installed`), and the revert
removes precisely that list — kitty, fish, ranger, Steam, OpenRGB, GameMode,
MangoHud, Docker, codecs, fonts, virt-manager, VirtualBox, flatpak itself, etc.
**`git` is always protected** and never uninstalled, even though the setup
installs it. If no record exists (a machine set up by an older version of the
script), the revert asks whether you want to fall back to removing the full
base + gaming package lists instead.

`r5` (terminal) is a full undo: it removes the deployed fish/kitty/ranger
configs **and** puts your login shell back to whatever it was before the
setup (saved by the installer; falls back to bash if unknown). After any
revert, log out & back in so the shell / docker group / environment changes
are fully applied.

**Windows** uses the same idea with a simpler start menu:

```
  What do you want to do?
    [1] Full setup (11 steps)
    [2] Revert - uninstall what this setup added
    [0] Quit
```

Pick `2` to go straight to the uninstall flow (same as the `-Revert` flag).

### 3. The plan + confirmation

Before executing anything the script prints the full plan with a one-line
summary of **what each stage actually installs or changes**, then asks for a
final `y/N`:

```
  Plan — 3 stage(s):
    • repos — Add RPM Fusion, Flathub and Docker repositories
    • packages — Base CLI tools, codecs, fonts + git/gh/neovim
    • gaming — GPU drivers, Steam, GameMode, MangoHud, GameScope

Proceed with the plan above? [y/N]
```

- Answer **`y`** → the stages run in order.
- Answer **`n`** → everything stops, nothing is changed.
- The summaries come from `lib/stages.sh` (`STAGE_SUMMARY` map), so they stay
  in sync with the stage registry.

The confirmation is **skipped automatically** when any of these is true:
- `--yes` was passed
- stdout is not a terminal (piped / CI / container without a TTY)
- `--dry-run` is active (nothing will change anyway)

### 4. Execution

Each stage prints its own `section` header, installs with a real progress bar
or spinner, and logs everything to `~/.config/linux-win-setup.log`. Completed
stages are recorded in `~/.config/linux-win-setup-state*.done`, so a failed
run can be resumed with `--resume` instead of starting over.

```
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ◆ Flatpak applications
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Sandboxed desktop apps from Flathub (auto-updated).
  ✓ app.zen_browser.zen installed
  ✓ com.discordapp.Discord installed
  ...
```

### Quick reference — all flags

```bash
sudo ./setup.sh                # interactive stage picker
sudo ./setup.sh --all          # run every stage in order
sudo ./setup.sh --stages 1,3,5 # repositories, packages, terminal
sudo ./setup.sh --minimal      # terminal + browser only
sudo ./setup.sh --resume       # continue where the last run stopped
sudo ./setup.sh --dry-run --all  # preview everything, zero changes
sudo ./setup.sh --yes          # skip all interactive prompts
sudo ./setup.sh --log /path/file.log  # custom log location
sudo ./setup.sh --help         # usage for the detected platform
```

---

## 🐧 Linux setup (10 stages)

| # | Stage | What it does |
|---|-------|--------------|
| 1 | **Repositories** | Adds distro sources: RPM Fusion (Fedora), Docker CE, Flathub |
| 2 | **System update** | `dnf5 upgrade` / `apt upgrade` / `pacman -Su` + `flatpak update` |
| 3 | **Base packages** | CLI tools, codecs, editors, fonts — from `manifests/base-*.txt` |
| 4 | **Flatpak apps** | Sandboxed apps from `manifests/apps-flatpak.txt` |
| 5 | **Terminal** | Explains **why** kitty + fish / zsh+starship+tmux, then asks your preference |
| 6 | **Browser** | Multi-select: Zen / Chrome / Brave / **Helios** — any or all; Firefox removal only with confirmation |
| 7 | **Gaming** | GameMode, AMD GPU tuning, env vars, sysctl |
| 8 | **Docker** | Native engine **or** Docker Desktop — you choose at prompt time |
| 9 | **Extras** | Optional dev/AI tools — multi-select checklist |
| 10 | **Cleanup** | Removes orphans + unused flatpak runtimes |

### Docker (stage 8) — two ways, you choose

At prompt time the script asks how you want Docker installed:

```
  How do you want Docker installed?
    [1] Native engine (recommended, no GUI)
    [2] Docker Desktop (official GUI app)
    [3] Skip Docker setup
  Select [1-3]:
```

| Option | What you get |
|---|---|
| **1. Native engine** | `docker-ce` + `compose` plugin, `~/.docker` config (build GC + compose hints), on-demand `docker.socket`, user added to the `docker` group |
| **2. Docker Desktop** | The official GUI app (`.deb`/`.rpm` latest build from `desktop.docker.com`, or AUR on Arch), bundled engine, per-user service enabled |

> **Docker Desktop is an *alternative*, not an add-on.** It ships its own
> VM-backed engine, so nothing native is installed when you pick it. It needs
> **KVM** (`/dev/kvm`) and a graphical session — the script warns if KVM is
> missing and skips gracefully.

### Optional extras (stage 9) — multi-select checklist

Stage 9 is a checklist of dev/AI tools you can opt into, one by one or all at
once. **Everything is optional** — nothing here is installed unless you pick
it:

```
  Which extras do you want to install?
  (comma list like 1,3,5 | a = all | n = none)
    [1]  Ollama — run local LLMs (llama3, qwen, hermes3…)
    [2]  opencode — AI coding agent in your terminal
    [3]  Claude Code — Anthropic's AI coding agent
    [4]  Gemini CLI — Google's AI coding agent
    [5]  Codeium — AI coding agent / completions
    [6]  uv — fast Python package manager
    [7]  fnm + pnpm — Node manager + packages (npm-free)
    [8]  rustup — Rust toolchain
    [9]  pipx — install Python CLIs in isolated envs
   [10]  VS Code — Microsoft's editor (Flatpak)
   [11]  Cursor — AI-first editor (own installer)
   [12]  Antigravity — Google's AI editor (own installer)
   [13]  Postman — API client (REST/graphQL, Flatpak)
   [14]  Insomnia — API client (REST/graphQL, Flatpak)
   [15]  Bitwarden — password manager (Flatpak)
   [16]  KeePassXC — offline password manager (Flatpak)
   [17]  1Password — password manager (Flatpak)
   [18]  Notion — notes & docs (Flatpak)
   [19]  Mission Center — system monitor (Flatpak)
   [20]  Bottles — run Windows apps/games (Flatpak)
   [21]  virt-manager — KVM/QEMU virtual machines (GUI)
   [22]  GNOME Boxes — KVM/QEMU virtual machines (simple GUI)
   [23]  VirtualBox — Oracle VirtualBox (its own hypervisor)
  Select: 1,3,9
```

| Tool | Installer | Notes |
|---|---|---|
| **Ollama** | official user installer | `ollama run llama3` to pull a model |
| **opencode** | official installer | open-source AI coding agent |
| **Claude Code** | official installer | Anthropic's agentic CLI (`claude`) |
| **Gemini CLI** | official installer | Google's agentic CLI (`gemini`) |
| **Codeium** | official installer | AI completions + agent (`codeium`) |
| **uv** | astral install.sh | Python env/packages |
| **fnm + pnpm** | official installers | Node manager + packages |
| **rustup** | sh.rustup.rs | Rust toolchain |
| **pipx** | system package | isolated Python CLIs |
| **VS Code** | Flatpak | Microsoft's editor |
| **Cursor** | own installer | AI-first editor (AppImage) |
| **Antigravity** | own installer | Google's AI editor |
| **Postman** | Flatpak | API client |
| **Insomnia** | Flatpak | open-source API client |
| **Bitwarden** | Flatpak | password manager (optional — not default) |
| **KeePassXC** | Flatpak | offline password manager |
| **1Password** | Flatpak | password manager |
| **Notion** | Flatpak | notes & docs |
| **Mission Center** | Flatpak | system monitor |
| **Bottles** | Flatpak | run Windows apps/games |
| **virt-manager** | system package | KVM/QEMU GUI (installs the libvirt + QEMU backend) |
| **GNOME Boxes** | Flatpak | KVM/QEMU GUI (shares the same backend as virt-manager) |
| **VirtualBox** | system package | own hypervisor; needs kernel modules (`virtualbox-dkms`/`-host-dkms`) |

> VirtualBox and KVM/QEMU are independent hypervisors — installing both is fine,
> but never run a VM on the two backends at the same time.

> **npm is intentionally not offered.** The npm registry has had supply-chain
> malware incidents, so this setup uses standalone installers plus
> **fnm** (Node version manager) and **pnpm** (packages). Install npm yourself
> only if you really need it.
>
> User-level installers (Ollama, uv, fnm, pnpm, rustup) run as **your** user
> even when the script runs with sudo, so everything lands in your `$HOME`.
> Already-installed tools are detected and skipped.

### State, resume & logs

The script is designed to be **interrupted without losing progress**:

| File | Purpose |
|---|---|
| `~/.config/linux-win-setup.log` | Every message (info/ok/skip/warn/fail) with a timestamp |
| `~/.config/linux-win-setup-state.done` | Stages completed successfully |
| `~/.config/linux-win-setup-state.failed` | Stages that errored |

- **`--resume`** re-runs only the stages missing from `state.done`. If a run
  fails halfway (power loss, bad network, wrong answer), just run
  `sudo ./setup.sh --resume` and it continues where it stopped.
- **`--dry-run`** never touches the state files — it's purely a preview.
- State is written **per stage**, not per package: a stage is only marked done
  when it returns exit code 0.

### Packages (edit `manifests/`)
The full list is **your power**: each family has its own file, commented and
version-agnostic. Examples:

| Fedora (`base-fedora.txt`) | Debian/Ubuntu (`base-debian.txt`) | Arch (`base-arch.txt`) |
|---|---|---|
| `dnf5` | `apt` | `pacman` |
| fish · kitty · fastfetch | fish · kitty · fastfetch | fish · kitty · fastfetch |
| eza · bat · fd-find · fzf · zoxide · rg | eza · bat · fd-find · fzf · zoxide · rg | eza · bat · fzf · zoxide · rg |
| jetbrains-mono-fonts | fonts-jetbrains-mono | ttf-jetbrains-mono-nerd |
| ffmpeg + gstreamer (RPM Fusion) | ffmpeg + gstreamer | ffmpeg + gst-plugins-* |
| docker-ce + plugins | docker-ce + plugins | docker + buildx + compose |

> Flatpak apps are shared across distros: Zen, Discord, Heroic,
> OBS, Spotify, Stremio, **goverlay**, WhatsApp, Obsidian, ProtonUp-Qt,
> **NetworkDisplays**, Kdenlive, LibreOffice, SQLiteBrowser, Telegram, VLC.
> Password managers (Bitwarden/KeePassXC/1Password), API clients
> (Postman/Insomnia) and editors are **optional** extras in stage 9.

### Gaming tuning (stage 7)

| Piece | Effect |
|---|---|
| `gpu-performance.service` | Pins the AMD GPU to **high** power to stop Wayland stutter (game/desktop freezes) |
| `gpu-performance-watch.path` | Re-applies it if anything resets the GPU clock |
| `udev/99-amd-gpu-high.rules` | Kernel-level fallback, independent of systemd |
| `environment.d/*.conf` | `PROTON_FSR4_UPGRADE=1` (FSR4), `STEAM_USE_WAYLAND=1`, RADV perftest |
| `profile.d/gamemode-gaming.sh` | `PROTON_ENABLE_GAMEMODE=1` for every session |
| `sysctl/*.conf` | `swappiness=1`, inotify limits, kernel hardening |

> Skips automatically if no AMD GPU is detected, or inside WSL/containers.

---

## 🖥️ Terminal guide (why kitty + fish / zsh+starship+tmux, and the shortcuts)

The setup **asks first** — some people come from Debian/WSL and prefer the
stock terminal. You get four options:

```
[1] kitty + fish (full setup — recommended)
[2] fish only     (for WSL/Debian or if you keep your terminal)
[3] zsh + starship + tmux  (the "zsh + starship + tmux with modern CLIs"
    setup — a zsh shell with the starship prompt, the tmux multiplexer and
    the modern CLIs: eza, bat, zoxide, fzf, fd, ripgrep)
[4] skip
```

Whatever you pick, this is what the config gives you:

### kitty (GPU terminal)
- **GPU rendering** → smooth scrolling, huge scrollback, 10000 lines.
- **Mouse UX**: select = copy · right-click = paste · Ctrl+click = open link.
- **Tabs** powerline-style (top bar) + transparent background (if composited).

| Shortcut | Action |
|---|---|
| `Ctrl+Shift+T` | New tab |
| `Ctrl+Shift+N` | New window (split) |
| `Ctrl+Shift+W` | Close tab |
| `Ctrl+Shift+C / V` | Copy / paste |
| Scroll | Browse 10000-line history |

### fish
- **Auto-suggestions** in grey — press **→** to accept the suggestion.
- **Syntax colors** change live: a GREEN command means it's installed,
  RED means it isn't. (Catppuccin Frappe colors.)
- `command not found` suggests the package to `dnf/apt/pacman` install.
- Tab-completions for the `copilot` CLI (GitHub Copilot agent) if you install it.

| Command | What it does |
|---|---|
| `ls` / `ll` / `la` / `lt` | `eza` with icons, git + tree |
| `cat` / `catp` | `bat` (pretty) / plain |
| `ff` <pattern> | `fd` |
| `z <dir>` / `zi` | smart cd (zoxide) |
| `Ctrl+R` / `Ctrl+T` / `Alt+C` | fzf history / files / cd |
| `rgf` | `rg --files` |

> The rest of fish is stock fish so it works for everyone: use `fish_config`
> to tune your prompt visually, `abbr` for your own abbreviations.

### ranger (TUI file manager)

Installed with the base packages and pre-configured: miller columns with
preview pane, git-aware statusline, relative line numbers and the jungle
colorscheme. `zh` toggles hidden files, `S` opens a shell in the current
folder.

### zsh + starship + tmux (option 3)

- **starship** prompt (Catppuccin Mocha) — directory, git status, toolchain
  versions (Python/Node/Rust), command duration and clock on the right.
- **zsh-syntax-highlighting**: a GREEN command means it's installed, RED
  means it isn't (Catppuccin Frappe colors).
- **zsh-autosuggestions** in grey — press **→** to accept the suggestion.
- **tmux** multiplexer: mouse on, split with `|` / `-`, new window from the
  current folder, windows renumber automatically. Reload config with `Ctrl+b r`.
- `command not found` suggests the package to `dnf/apt` install.

| Command | What it does |
|---|---|
| `ls` / `ll` / `la` / `lt` | `eza` with icons, git + tree |
| `cat` / `catp` | `bat` (pretty) / plain |
| `ff` <pattern> | `fd` |
| `z <dir>` / `zi` | smart cd (zoxide) |
| `Ctrl+R` / `Ctrl+T` / `Alt+C` | fzf history / files / cd |
| `rgf` | `rg --files` |
| `t` / `ta` | `tmux` / `tmux attach` |

---

## 🪟 Windows 11 (setup-windows.ps1)

The Windows script is **fully interactive** — every step asks what you want
and installs only what you pick. Nothing is forced.

1. **System base** — Windows Update + GPU vendor driver (NVIDIA / AMD / Intel), detected automatically.
2. **Browsers** — multi-select: Zen · Chrome · Brave · **Helios** · **Firefox** (Windows 11 ships with Edge preinstalled, so every option here is an addition or replacement — none is forced). Edge removal is offered separately, never forced.
3. **Communications** — multi-select: Discord · Telegram · WhatsApp.
4. **Media** — multi-select: VLC · Spotify · Stremio · OBS.
5. **Productivity** — multi-select: LibreOffice · Obsidian · PyCharm · DB Browser · Notion.
6. **Dev tools** — each is a choice:
   - **Editor**: VS Code · Cursor · Antigravity.
   - **API client**: Postman · Insomnia.
   - **AI coding agent**: Claude Code · opencode · Gemini CLI · Codeium.
   - **Password manager**: Bitwarden · KeePassXC · 1Password (Bitwarden is *not* the default — you choose).
   - **Git + GitHub CLI** and **Docker Desktop** — asked, optional.
7. **Gaming** — multi-select: Steam · Heroic · **Epic Games Launcher** + tweaks (**Game DVR off**, **High performance** power plan), asked with confirmation.
8. **Virtual machines** — VirtualBox / Hyper-V / Both / None (you choose).
9. **Cleanup** — `winget upgrade --all` + `cleanmgr`, asked.

> Use WSL (`wsl/setup-wsl.sh`) to bring the fish setup into Windows when you
> prefer a Linux CLI.

---

## 📦 What is **not** automated

| Item | Why |
|---|---|
| fstab UUIDs (multiboot disks) | Hardware-specific; the README shows the safe template |
| Wi-Fi / network passwords | You enter them in the DE or with `nmcli` |
| SSH keys / `gh auth` | Credentials are yours alone |
| KDE theme / desktop layout | Visual preference — install from the Plasma Store |
| GE-Proton versions | Install per-game with ProtonUp-Qt |
| `chattr +C` for btrfs games | Do it after mounting your game drive |

---

## ❓ FAQ

**Is this a distro?** No. It runs on your existing Fedora, Debian/Ubuntu or
Arch install and just adds the tools/configs you pick.

**Can I undo everything?** Yes — `./setup.sh --revert` (or the Windows
`-Revert` flag) removes exactly what the script installed, based on the
install-time record. Things you had before the setup are left alone. **Git is
protected and never uninstalled on either platform.** The revert now
**forces uninstallation** of all recorded packages, even if they are
pre-existing, so you won't see "already installed" skips. On Windows, the
uninstaller is **multi-method**: it tries `winget`, then **MSIX / Microsoft
Store apps**, then the app's registry uninstaller (MSI / vendor installer),
then leftover-folder cleanup, so apps are removed regardless of how they were
installed. Apps that aren't installed are reported as skipped (not "removed").
A detailed final list shows exactly what was removed, what failed and what was
skipped.

**Will it overwrite my dotfiles?** Only the ones it deploys (fish/kitty/ranger
or zsh/starship/tmux configs), and only if you choose that terminal option.
It's not a live dotfile syncer.

**Does it work on NVIDIA / Intel GPUs?** The gaming stage detects your GPU.
AMD gets the full open-source tuning; on NVIDIA the script keeps going but the
proprietary drivers stay a manual step (they're a licensing thing, not a
script limitation).

**Why only one terminal / file manager, but browsers are multi-select?** Terminals
and file managers are workflow tools — installing five of them wastes disk and
confuses the muscle memory, so the script asks your preference and installs
just one of each. Browsers are a personal choice (privacy, extensions, work vs
personal), so there you can pick any or all of them.

**Is it safe to re-run?** Yes. Every stage is idempotent, and already-installed
tools are detected and skipped.

---

## 🗂 How the project is organized

One repo, three setup targets — and they share the same "visual language"
(banner, colored checks, progress bars, ask-before-touching). Here is every
folder and what it is for:

```
linux-win-setup/
├── setup.sh                  ← Linux entry point. Detects your distro and runs
│                                linux/setup-linux.sh. This is the file you call.
├── README.md                 ← this file
├── LICENSE                   ← MIT
├── lib/                      ← shared UI + logic used by every Linux script
│   ├── banner.art            ← the ASCII logo (one source of truth, shared)
│   ├── ui.sh                 ← colors, gradient banner, progress bars, spinners,
│   │                            prompts (yes/no, lists, multi-select) and logging
│   ├── os.sh                 ← distro detection + the apt/dnf/pacman wrappers
│   │                            (one install command that works on all three)
│   └── stages.sh             ← stage registry, interactive menu, the "plan",
│                                resume state and the revert helpers
├── linux/
│   ├── setup-linux.sh        ← Linux orchestrator: parses flags, builds the
│   │                            plan, runs the stages you picked
│   ├── manifests/            ← plain-text package lists, one per distro family:
│   │                            base-fedora.txt, base-debian.txt, base-arch.txt,
│   │                            gaming-*.txt, apps-flatpak.txt, wsl-debian.txt
│   │                            (edit these to add/remove packages, no code)
│   ├── stages/               ← one file per step of the setup (stage_*.sh):
│   │                            repos, update, packages, apps, terminal, browser,
│   │                            gaming, docker, extra, cleanup, revert
│   └── configs/              ← the dotfiles/tuning the setup deploys: fish,
│                                kitty, zsh+starship+tmux, ranger, environment.d,
│                                systemd units, udev rules, sysctl
├── windows/
│   └── setup-windows.ps1     ← Windows 11 setup (winget). Pure ASCII on purpose
│                                (PowerShell 5.1 reads .ps1 as ANSI). Started via
│                                setup-windows.cmd (keeps the window open).
├── scripts/
│   └── check.sh              ← repo-wide static checks: bash -n, ShellCheck,
│                                PowerShell parse and a secret scan
└── wsl/
    └── setup-wsl.sh          ← lightweight setup for WSL (fish + CLI tools)
```

### What each top-level file does

| File / folder | What it does | When you'd touch it |
|---|---|---|
| `setup.sh` | Linux entry point: detects OS, hands off to `linux/setup-linux.sh` | Never — just run it |
| `lib/ui.sh` | Colors, banner, progress bars, spinners, prompts, logging | To change the look of the Linux UI |
| `lib/os.sh` | Distro detection + `apt`/`dnf`/`pacman` wrappers | To support a new distro |
| `lib/stages.sh` | Stage registry, menu, plan, resume, revert | To add a new stage or menu entry |
| `lib/banner.art` | The shared ASCII logo | To change the logo |
| `linux/manifests/` | Package lists per distro (plain text) | **To add/remove packages — edit here, no coding** |
| `linux/stages/` | One file per setup step | To change what a step does |
| `linux/configs/` | The dotfiles and tuning the setup deploys | To tweak the configs you get |
| `windows/setup-windows.ps1` | The whole Windows 11 setup | To change the Windows experience |
| `scripts/check.sh` | Static checks for the whole repo | To validate after your changes |
| `wsl/setup-wsl.sh` | Lightweight WSL setup | To change the WSL toolset |

### Why this layout

- **`lib/` is shared** so Fedora, Debian, Arch and WSL render the *same* banner,
  checks and progress bars — one UI, one source of truth.
- **`manifests/` separate data from code**: adding a package is a text edit,
  not a script change.
- **`stages/` are one concern each**: you can reason about (or revert) "gaming"
  without reading the rest of the setup.
- **`configs/` mirrors your dotfiles**: what you get is visible before you run
  anything, and revert can remove exactly it.
- **`windows/` is self-contained** (ASCII, no shared bash) because PowerShell is
  a different runtime — but it mirrors the Linux flow so the experience is the same.
- **`scripts/` keeps quality in one place**: contributors can run one command
  to validate every Linux shell script and the Windows PowerShell file.

---

## 🔒 Security & trust

**This is not a virus — and you don't have to take our word for it.**

- **100% open source (MIT).** Every line of this repo is human-readable and
  reviewable. There is no obfuscated code, no telemetry, no hidden downloads and
  no calls to anything but the official package sources (your distro's repos,
  Flathub, winget, Docker Hub).
- **Ask-first, always.** Nothing is installed, removed or modified without an
  explicit confirmation from you.
- **Windows may show a warning.** A *downloaded, unsigned PowerShell script*
  triggers Windows SmartScreen / Defender by design — it is a generic policy
  for *any* unsigned script from the internet, not a sign of malware. If you
  see *"Windows protected your PC"*, click **More info → Run anyway**.
- **`-ExecutionPolicy Bypass` is not "disabling the antivirus".** It only tells
  PowerShell to ignore the *execution policy* (a setting that blocks script
  files). Windows Defender and SmartScreen stay fully active.
- **How to verify it yourself:** read the source in this repo, run
  `scripts/check.sh` (it checks every Linux script for syntax errors), and in
  Windows review `windows/setup-windows.ps1` before running — it is a single
  readable file.
- **Best practice:** run it as your normal user (the script asks for elevation
  only when a step needs it), and only on a machine you own.

---

## 🤝 Get involved / Contributing

Found a bug, want a new app in the list, or an idea for a new stage? You're
welcome to contribute:

- **Open an issue** at
  [github.com/Davidxap/linux-win-setup/issues](https://github.com/Davidxap/linux-win-setup/issues)
  — bug reports, feature requests and "please add X" all go here.
- **Send a pull request.** The repo keeps a **single root commit** (squashed),
  so please **open an issue first** or mention your PR in an issue so we can
  coordinate. The usual flow:
  1. Fork the repo.
  2. Make your change (adding a package? just edit a file in `linux/manifests/`).
  3. Run `scripts/check.sh` to validate the Linux scripts, and the ASCII/balance
     check for `windows/setup-windows.ps1`.
  4. Open a PR against `main`.
- **Ideas that help most:** new apps in `manifests/`, more "tested on" rows,
  and bug reports with the setup log
  (`~/.config/linux-win-setup.log`).

---

## 📜 License

MIT — use it, change it, share it.

---

**Author**: [Davidxap](https://github.com/Davidxap) — built for people who
reinstall their OS and want a fresh, working setup without relearning or
re-memorizing every step.
