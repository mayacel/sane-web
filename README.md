# Sane dwl rice

<img width="1919" height="1079" alt="2026-08-20_17-53-50" src="https://github.com/user-attachments/assets/bcd71227-0f0e-4843-9293-970a03230b3c" />


A complete Arch Linux / Artix Linux rice built around **dwl**, **dwlb**,
**foot**, **wmenu**, **fnott** and a small set of direct desktop tools.

The repository is designed so a new user can clone it and let one installer do
the package installation, source compilation, dotfile deployment, dynamic
palette setup, application integration, Firefox cleanup, MIME defaults and
login-session setup.

```bash
git clone https://github.com/YOUR-USER/sane-dwl-rice.git
cd sane-dwl-rice
./install.sh
```

The installer must be run as a normal user with `sudo` access.

## What it installs

### Shell / compositor

- dwl v0.8, compiled from source with XWayland enabled.
- dwlb, compiled from a pinned upstream revision and patched for live colors.
- 5 tags; tiled is the default layout; floating and monocle remain functional
  tools rather than aesthetic defaults.
- 1 px borders, no compositor blur/shadow/rounded-corner layer.
- Brazilian keyboard layout by default (`SANE_KEYBOARD_LAYOUT=br`).

### Small desktop tools

- foot + Terminus
- wmenu
- fnott
- swaybg
- grim + slurp + wl-clipboard
- Thunar
- Firefox
- imv / imv-dir
- mpv
- zathura

### Dynamic Sane palette

`wallpaper -> wallust -> semantic palette -> shell/application roles`

The wallpaper supplies hue/accent candidates. The semantic layer supplies
stable UI roles such as `SURFACE`, `TEXT`, `BORDER`, `ACTIVE`, `SELECT` and
`URGENT`.

Light mode is structurally light. Dark mode is a wallpaper-tinted dark surface,
not a forced near-black theme.

```bash
sane-mode light
sane-mode dark
sane-wallpaper
sane-colors
```

### Firefox

Firefox uses one canonical userChrome/userContent source. The installer removes
known obsolete Sane CSS blocks before adding the current one, preventing old
`!important` rules from stacking.

The current setup:

- follows Firefox System Theme / GTK / XDG appearance;
- compact rectangular tabs and URL bar;
- no redundant client-side window buttons under dwl;
- no bookmarks import bar by default;
- minimal Firefox Home/New Tab;
- ordinary websites are not recolored.

### Thunar

Thunar defaults to a dense detailed file view with an editable literal path,
ISO dates and a quiet status line. The side pane is hidden by default but can be
toggled with `Ctrl+B`. Light/dark modes choose icon themes suitable for the
surface so the left-side icons remain readable.

### Images, video and PDF

Common image MIME types are routed through `sane-image.desktop` and the
`sane-image` wrapper. A single selected image opens through `imv-dir`, so the
left/right keys can browse sibling images in the same directory.

- images -> imv / imv-dir
- video -> mpv
- PDF -> zathura + mupdf backend

## Default keys

| Key | Action |
|---|---|
| `Super+Enter` | terminal |
| `Super+D` | launcher |
| `Super+E` | Thunar |
| `Super+B` | Firefox |
| `Super+C` | close window |
| `Super+V` | toggle floating |
| `Super+F` | fullscreen |
| `Super+A` | toggle dwlb |
| `Super+W` | choose wallpaper + regenerate palette |
| `Super+N` | dismiss notification |
| `Super+/` | key help |
| `Print` / `Super+Shift+S` | area screenshot |
| `Super+Shift+Print` | full screenshot |
| `Super+T` | tiled layout |
| `Super+Shift+V` | floating layout |
| `Super+M` | monocle |
| `Super+1..5` | select tag |
| `Super+Shift+1..5` | move window to tag |
| `Super+Shift+Q` | quit dwl |

## Installer options

Environment variables can be supplied before `./install.sh`:

```bash
SANE_KEYBOARD_LAYOUT=us ./install.sh
SANE_MODE=dark ./install.sh
SANE_INSTALL_SDDM=no ./install.sh
SANE_JOBS=4 ./install.sh
```

Useful options:

- `SANE_KEYBOARD_LAYOUT=br` — xkb layout baked into dwl at compilation.
- `SANE_MODE=light|dark` — initial mode.
- `SANE_INSTALL_SDDM=auto|yes|no` — by default SDDM is installed only when no
  known display manager exists.
- `SANE_FULL_UPGRADE=1|0` — default `1`; performs `pacman -Syu` before install.
- `SANE_BUILD_ROOT=...` — source/build directory.
- `SANE_JOBS=...` — parallel build jobs.

## Arch and Artix

The installer detects `/etc/os-release` and the init system.

- Arch/systemd: normal package install and optional SDDM service enable.
- Artix/OpenRC: installs/enables the OpenRC dbus/elogind services and uses
  `sddm-openrc` when it needs to install SDDM.

It does not require systemd user services for the rice itself.

## Updating

```bash
./update.sh
```

This creates another backup, updates packages by default, refreshes source,
recompiles dwl/dwlb and reapplies the repository state.

## Uninstall / restore

```bash
./uninstall.sh
```

The uninstall script restores the most recent pre-install backup. Packages are
left installed deliberately, and display-manager services are not disabled.

## Diagnostics

```bash
sane-doctor
sane-firefox-status
sane-image-status
```

For display-specific settings:

```bash
wlr-randr
cp ~/.config/dwl/output.sh.example ~/.config/dwl/output.sh
chmod +x ~/.config/dwl/output.sh
$EDITOR ~/.config/dwl/output.sh
```

## Repository layout

```text
assets/wallpapers/            included wallpapers
bin/                          installed Sane commands
config/dwl/                   dwl build-time configuration
config/dwlb/                  dwlb build-time configuration
dotfiles/.config/             user configuration copied to ~/.config
firefox/                      canonical Firefox CSS
lib/                          semantic palette / app configuration logic
tools/                        source patches and build helper
docs/                         architecture, customization, troubleshooting
.github/workflows/            repository validation/smoke build
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the data flow and
[`docs/CUSTOMIZATION.md`](docs/CUSTOMIZATION.md) before editing generated
colors by hand.

## Wallpaper copyright

The code is MIT licensed. The included wallpapers are intentionally documented
separately because image redistribution rights are not established by the code
license. Read [`assets/wallpapers/README.md`](assets/wallpapers/README.md)
before publishing a public fork.
