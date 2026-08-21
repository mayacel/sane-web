#!/bin/bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo dev)"
STATE="$HOME/.local/state/sane-rice"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$STATE/backups/$STAMP"

SANE_KEYBOARD_LAYOUT="${SANE_KEYBOARD_LAYOUT:-br}"
SANE_MODE="${SANE_MODE:-light}"
SANE_INSTALL_SDDM="${SANE_INSTALL_SDDM:-auto}"
SANE_FULL_UPGRADE="${SANE_FULL_UPGRADE:-1}"
SANE_WALLUST_VERSION="${SANE_WALLUST_VERSION:-3.5.2}"
export SANE_KEYBOARD_LAYOUT

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "run ./install.sh as your normal user, not as root"
command -v pacman >/dev/null 2>&1 || die "pacman not found; this installer targets Arch Linux and Artix Linux"
command -v sudo >/dev/null 2>&1 || die "sudo is required"
[ -r /etc/os-release ] || die "/etc/os-release is missing"
# shellcheck disable=SC1091
. /etc/os-release

case "${ID:-}" in
  arch) DISTRO=arch ;;
  artix) DISTRO=artix ;;
  *)
    if printf '%s\n' "${ID_LIKE:-}" | grep -qw arch; then
      DISTRO=archlike
      warn "${ID:-unknown} is Arch-like but not explicitly tested; continuing"
    else
      die "unsupported distribution: ${ID:-unknown}"
    fi
    ;;
esac

INIT=unknown
if command -v rc-update >/dev/null 2>&1; then INIT=openrc; fi
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then INIT=systemd; fi
if [ "$DISTRO" = artix ] && [ "$INIT" != openrc ]; then
  warn "Artix detected without OpenRC. Package installation continues, but service setup may need manual adjustment."
fi

case "$SANE_MODE" in light|dark) ;; *) die "SANE_MODE must be light or dark" ;; esac

mkdir -p "$BACKUP/home" "$BACKUP/root" "$STATE"
printf '%s\n' "$BACKUP" > "$STATE/last-backup"
printf 'version=%s\ndistro=%s\ninit=%s\nkeyboard=%s\nmode=%s\n' \
  "$VERSION" "$DISTRO" "$INIT" "$SANE_KEYBOARD_LAYOUT" "$SANE_MODE" > "$BACKUP/meta"

backup_home() {
  local rel="$1"
  if [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ]; then
    mkdir -p "$BACKUP/home/$(dirname "$rel")"
    cp -a "$HOME/$rel" "$BACKUP/home/$rel"
    printf '%s\n' "$rel" >> "$BACKUP/home-existed.txt"
  fi
}
backup_root() {
  local path="$1" rel
  if sudo test -e "$path"; then
    rel="${path#/}"
    mkdir -p "$BACKUP/root/$(dirname "$rel")"
    sudo cp -a "$path" "$BACKUP/root/$rel"
    sudo chown -R "$(id -u):$(id -g)" "$BACKUP/root/$rel" 2>/dev/null || true
    printf '%s\n' "$path" >> "$BACKUP/root-existed.txt"
  fi
}

say "Sane dwl rice $VERSION — $DISTRO / $INIT"
printf 'user: %s\nkeyboard: %s\ninitial mode: %s\nbackup: %s\n' "$USER" "$SANE_KEYBOARD_LAYOUT" "$SANE_MODE" "$BACKUP"
sudo -v

say "1/12 — backup current configuration"
for rel in \
  .config/dwl .config/foot .config/sane .config/wallust .config/xdg-desktop-portal \
  .config/gtk-3.0 .config/imv .config/zathura .config/mpv .config/mimeapps.list \
  .local/share/applications/sane-image.desktop .local/share/themes/SaneLiveA .local/share/themes/SaneLiveB \
  Pictures/wallpapers/sane-current.jpg Pictures/wallpapers/garden-kitten.jpg Pictures/wallpapers/clouds.jpg .bashrc
 do
  backup_home "$rel"
done
for path in \
  /usr/local/bin/dwl /usr/local/bin/dwlb /usr/local/bin/dwl-session \
  /usr/local/lib/sane-rice /usr/local/share/sane-rice /usr/local/bin/wallust \
  /usr/share/wayland-sessions/sane-dwl.desktop
 do
  backup_root "$path"
done
for f in "$ROOT"/bin/*; do
  backup_root "/usr/local/bin/$(basename "$f")"
done

# Firefox config is user data; back up only the files this rice edits, not the whole profile.
mkdir -p "$BACKUP/firefox"
for base in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
  [ -d "$base" ] || continue
  tag="$(printf '%s' "$base" | sed 's#^/##; s#/#__#g')"
  mkdir -p "$BACKUP/firefox/$tag"
  while IFS= read -r -d '' f; do
    rel="${f#$base/}"
    mkdir -p "$BACKUP/firefox/$tag/$(dirname "$rel")"
    cp -a "$f" "$BACKUP/firefox/$tag/$rel"
  done < <(find "$base" -type f \
    \( -name prefs.js -o -name user.js -o -path '*/chrome/userChrome.css' -o -path '*/chrome/userContent.css' -o -path '*/chrome/sane-colors.css' \) \
    -print0 2>/dev/null)
done

say "2/12 — install Arch/Artix packages"
REQUIRED=(
  base-devel git pkgconf python rust
  wlroots0.19 libinput wayland wayland-protocols libxkbcommon libxcb xcb-util-wm xorg-xwayland
  fcft pixman
  foot terminus-font wmenu fnott swaybg wlr-randr grim slurp wl-clipboard libnotify
  thunar tumbler ffmpegthumbnailer thunar-archive-plugin file-roller gvfs udisks2
  firefox imv mpv zathura zathura-pdf-mupdf
  xdg-utils xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-gtk desktop-file-utils shared-mime-info
  gsettings-desktop-schemas dconf gtk3 adwaita-icon-theme breeze-icons polkit polkit-gnome
  fastfetch unzip zip 7zip pciutils
)
if [ "$DISTRO" = artix ]; then
  REQUIRED+=(dbus dbus-openrc elogind elogind-openrc)
else
  REQUIRED+=(dbus)
fi

# Optional quality-of-life packages: install only when present in enabled repos.
OPTIONAL=(thunar-volman adwaita-cursors)
for pkg in "${OPTIONAL[@]}"; do
  if pacman -Si "$pkg" >/dev/null 2>&1; then REQUIRED+=("$pkg"); fi
done

if [ "$SANE_FULL_UPGRADE" = 1 ]; then
  sudo pacman -Syu --needed "${REQUIRED[@]}"
else
  # Useful for repo development/update runs. A full -Syu is recommended on Arch.
  sudo pacman -S --needed "${REQUIRED[@]}"
fi
xdg-user-dirs-update || true

if [ "$DISTRO" = artix ] && [ "$INIT" = openrc ]; then
  sudo rc-update add dbus default 2>/dev/null || true
  sudo rc-update add elogind boot 2>/dev/null || true
fi

say "3/12 — install wallust"
if ! command -v wallust >/dev/null 2>&1; then
  WROOT="$HOME/.cache/sane-rice/wallust-root"
  rm -rf "$WROOT"
  mkdir -p "$WROOT"
  if ! cargo install wallust --version "$SANE_WALLUST_VERSION" --locked --root "$WROOT"; then
    warn "pinned wallust $SANE_WALLUST_VERSION failed; trying current crates.io release"
    cargo install wallust --locked --root "$WROOT"
  fi
  sudo install -m 0755 "$WROOT/bin/wallust" /usr/local/bin/wallust
fi
wallust --version || true

say "4/12 — compile and install dwl + dwlb"
"$ROOT/tools/build-components.sh" "$ROOT"

say "5/12 — install Sane scripts and libraries"
sudo install -d -m 0755 /usr/local/lib/sane-rice /usr/local/share/sane-rice/firefox
sudo install -m 0755 "$ROOT/lib/semantic.py" /usr/local/lib/sane-rice/semantic.py
sudo install -m 0755 "$ROOT/lib/thunar_layout.py" /usr/local/lib/sane-rice/thunar_layout.py
sudo install -m 0755 "$ROOT/lib/firefox_setup.py" /usr/local/lib/sane-rice/firefox_setup.py
sudo install -m 0644 "$ROOT/firefox/userChrome.css" /usr/local/share/sane-rice/firefox/userChrome.css
sudo install -m 0644 "$ROOT/firefox/userContent.css" /usr/local/share/sane-rice/firefox/userContent.css
for f in "$ROOT"/bin/*; do
  sudo install -m 0755 "$f" "/usr/local/bin/$(basename "$f")"
done
sudo install -m 0755 "$ROOT/bin/dwl-session" /usr/local/bin/dwl-session

say "6/12 — install dotfiles and wallpapers"
mkdir -p "$HOME/.config" "$HOME/Pictures/wallpapers" "$HOME/Pictures/Screenshots"
cp -a "$ROOT/dotfiles/.config/." "$HOME/.config/"
cp -a "$ROOT/assets/wallpapers/." "$HOME/Pictures/wallpapers/"
printf '%s\n' "$HOME/Pictures/wallpapers/sane-current.jpg" > "$HOME/.config/dwl/wallpaper"
printf '%s\n' "$SANE_MODE" > "$HOME/.config/sane/mode"
chmod +x "$HOME/.config/dwl/start"

# Prompt is local to the graphical rice, not SSH/TTY sessions.
python3 - "$HOME/.bashrc" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1])
old=p.read_text(errors='ignore') if p.exists() else ''
b='# SANE_RICE_SHELL_BEGIN'; e='# SANE_RICE_SHELL_END'
old=re.sub(re.escape(b)+r'.*?'+re.escape(e)+r'\n?','',old,flags=re.S)
block=(
    '# SANE_RICE_SHELL_BEGIN\n'
    'if [ "${SANE_RICE:-0}" = "1" ] && [ -r "$HOME/.config/sane/prompt.sh" ]; then\n'
    '    . "$HOME/.config/sane/prompt.sh"\n'
    'fi\n'
    '# SANE_RICE_SHELL_END\n'
)
p.write_text(old.rstrip()+'\n\n'+block)
PY

say "7/12 — configure Thunar, image/video/PDF handlers"
# Stop daemons before changing xfconf/XML and GTK startup styling.
thunar -q 2>/dev/null || true
pkill -x Thunar 2>/dev/null || true
pkill -x xfconfd 2>/dev/null || true
python3 /usr/local/lib/sane-rice/thunar_layout.py

mkdir -p "$HOME/.local/share/applications"
install -m 0644 "$ROOT/config/sane-image.desktop" "$HOME/.local/share/applications/sane-image.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

xdg-mime default thunar.desktop inode/directory || true
xdg-mime default firefox.desktop text/html || true
xdg-mime default firefox.desktop application/xhtml+xml || true
xdg-mime default firefox.desktop x-scheme-handler/http || true
xdg-mime default firefox.desktop x-scheme-handler/https || true
for mime in \
  image/png image/jpeg image/gif image/webp image/bmp image/tiff image/svg+xml \
  image/heif image/heic image/avif image/jxl \
  image/x-portable-pixmap image/x-portable-graymap image/x-portable-bitmap
 do xdg-mime default sane-image.desktop "$mime" || true; done
for mime in video/mp4 video/x-matroska video/webm video/mpeg video/quicktime video/x-msvideo
 do xdg-mime default mpv.desktop "$mime" || true; done
xdg-mime default org.pwmt.zathura.desktop application/pdf || true

say "8/12 — initialize and configure Firefox"
# Firefox profile locations differ across Linux builds. Create one if this is a fresh user.
if ! find "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox" -type f -name prefs.js -print -quit 2>/dev/null | grep -q .; then
  TMP_SHOT="$HOME/.cache/sane-rice/firefox-init.png"
  mkdir -p "$(dirname "$TMP_SHOT")"
  timeout 25s firefox --headless --screenshot "$TMP_SHOT" about:blank >/dev/null 2>&1 || true
fi

# prefs.js is Firefox-owned. Stop Firefox before the one-time cleanup.
pkill -TERM -x firefox 2>/dev/null || true
for _ in $(seq 1 30); do
  pgrep -x firefox >/dev/null 2>&1 || break
  sleep 0.2
done
if pgrep -x firefox >/dev/null 2>&1; then
  warn "Firefox did not stop quickly; skipping prefs.js cleanup to avoid corruption"
else
  python3 /usr/local/lib/sane-rice/firefox_setup.py apply /usr/local/share/sane-rice/firefox
fi

say "9/12 — install Wayland session and configure display manager"
sudo install -m 0644 "$ROOT/config/sane-dwl.desktop" /usr/share/wayland-sessions/sane-dwl.desktop

have_dm=0
for dm in sddm gdm lightdm greetd; do
  command -v "$dm" >/dev/null 2>&1 && have_dm=1
 done
want_sddm=0
case "$SANE_INSTALL_SDDM" in
  1|yes|true) want_sddm=1 ;;
  0|no|false) want_sddm=0 ;;
  auto) [ "$have_dm" -eq 0 ] && want_sddm=1 || true ;;
  *) warn "unknown SANE_INSTALL_SDDM=$SANE_INSTALL_SDDM; using auto"; [ "$have_dm" -eq 0 ] && want_sddm=1 || true ;;
esac

if [ "$want_sddm" -eq 1 ]; then
  if [ "$DISTRO" = artix ]; then
    sudo pacman -S --needed sddm sddm-openrc
  else
    sudo pacman -S --needed sddm
  fi
fi

if command -v sddm >/dev/null 2>&1; then
  if [ "$INIT" = openrc ]; then sudo rc-update add sddm default 2>/dev/null || true; fi
  if [ "$INIT" = systemd ]; then sudo systemctl enable sddm.service 2>/dev/null || true; fi
fi

say "10/12 — generate initial palette and application chrome"
sane-palette --no-live "$HOME/Pictures/wallpapers/sane-current.jpg"
sane-app-theme --quiet || true

# If Firefox profile appeared after palette setup, make sure canonical CSS is installed.
if ! pgrep -x firefox >/dev/null 2>&1; then
  python3 /usr/local/lib/sane-rice/firefox_setup.py apply /usr/local/share/sane-rice/firefox || true
fi

say "11/12 — validate desktop integration"
sane-image --self-test || true
sane-image-status || true
sane-firefox-status || true
sane-doctor || true

say "12/12 — finished"
cat <<EOF
Sane dwl rice $VERSION is installed.

Login session:
  Sane dwl

Useful commands:
  sane-mode light
  sane-mode dark
  sane-wallpaper
  sane-colors
  sane-doctor
  sane-firefox-status
  sane-image-status

Default keys:
  Super+Enter     terminal
  Super+D         launcher
  Super+E         Thunar
  Super+B         Firefox
  Super+W         wallpaper + palette
  Super+/         key help
  Super+Shift+Q   quit dwl

Backup created at:
  $BACKUP

If no display manager is enabled, start the session manually with:
  /usr/local/bin/dwl-session

For VirtualBox/VMware guests the session wrapper automatically enables the
wlroots software-cursor workaround when the virtual GPU is detected.
EOF
