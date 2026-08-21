#!/bin/bash
set -euo pipefail
STATE="$HOME/.local/state/sane-rice"
[ -s "$STATE/last-backup" ] || { echo 'No Sane rice backup was found.' >&2; exit 1; }
B="$(cat "$STATE/last-backup")"
[ -d "$B" ] || { echo "Backup directory is missing: $B" >&2; exit 1; }

if pgrep -x firefox >/dev/null 2>&1; then
  echo 'Closing Firefox before restoring its profile files...'
  pkill -TERM -x firefox 2>/dev/null || true
  for _ in $(seq 1 30); do pgrep -x firefox >/dev/null 2>&1 || break; sleep 0.2; done
fi
thunar -q 2>/dev/null || true
pkill -x Thunar 2>/dev/null || true
pkill -x xfconfd 2>/dev/null || true

restore_home() {
  local rel="$1"
  if [ -f "$B/home-existed.txt" ] && grep -Fxq "$rel" "$B/home-existed.txt"; then
    rm -rf "$HOME/$rel"
    mkdir -p "$HOME/$(dirname "$rel")"
    cp -a "$B/home/$rel" "$HOME/$rel"
  else
    rm -rf "$HOME/$rel"
  fi
}
restore_root() {
  local path="$1" rel="${1#/}"
  if [ -f "$B/root-existed.txt" ] && grep -Fxq "$path" "$B/root-existed.txt"; then
    sudo rm -rf "$path"
    sudo mkdir -p "$(dirname "$path")"
    sudo cp -a "$B/root/$rel" "$path"
  else
    sudo rm -rf "$path"
  fi
}

echo '[1/4] restoring home configuration'
for rel in \
  .config/dwl .config/foot .config/sane .config/wallust .config/xdg-desktop-portal \
  .config/gtk-3.0 .config/imv .config/zathura .config/mpv .config/mimeapps.list \
  .local/share/applications/sane-image.desktop .local/share/themes/SaneLiveA .local/share/themes/SaneLiveB \
  Pictures/wallpapers/sane-current.jpg Pictures/wallpapers/garden-kitten.jpg Pictures/wallpapers/clouds.jpg .bashrc
 do restore_home "$rel"; done
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo '[2/4] restoring Firefox files'
for base in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
  [ -d "$base" ] || continue
  tag="$(printf '%s' "$base" | sed 's#^/##; s#/#__#g')"
  src="$B/firefox/$tag"

  # Restore every file that existed at install time.
  if [ -d "$src" ]; then
    while IFS= read -r -d '' f; do
      rel="${f#$src/}"
      mkdir -p "$base/$(dirname "$rel")"
      cp -a "$f" "$base/$rel"
    done < <(find "$src" -type f -print0)
  fi

  # For files created by the rice after the backup, strip only Sane-owned blocks.
  python3 - "$base" "$src" <<'PY'
from pathlib import Path
import re,sys
base=Path(sys.argv[1]); src=Path(sys.argv[2])
blocks=[
('/* SANE_FIREFOX_CANONICAL_BEGIN */','/* SANE_FIREFOX_CANONICAL_END */'),
('/* SANE_FIREFOX_CANONICAL_NEWTAB_BEGIN */','/* SANE_FIREFOX_CANONICAL_NEWTAB_END */'),
('// SANE_FIREFOX_SYSTEM_PREFS_BEGIN','// SANE_FIREFOX_SYSTEM_PREFS_END'),
]
for f in list(base.glob('**/chrome/userChrome.css'))+list(base.glob('**/chrome/userContent.css'))+list(base.glob('**/user.js')):
    rel=f.relative_to(base)
    if (src/rel).exists():
        continue
    text=f.read_text(errors='ignore')
    old=text
    for b,e in blocks:
        text=re.sub(re.escape(b)+r'.*?'+re.escape(e)+r'\s*','',text,flags=re.S)
    if text != old:
        if text.strip(): f.write_text(text)
        else: f.unlink(missing_ok=True)
for f in base.glob('**/chrome/sane-colors.css.disabled-sane-rice'):
    original=f.with_name('sane-colors.css')
    if not original.exists(): f.rename(original)
PY
done

echo '[3/4] restoring system-installed rice files'
# Explicit core paths.
for path in \
  /usr/local/bin/dwl /usr/local/bin/dwlb /usr/local/bin/dwl-session \
  /usr/local/lib/sane-rice /usr/local/share/sane-rice /usr/local/bin/wallust \
  /usr/share/wayland-sessions/sane-dwl.desktop
 do restore_root "$path"; done

# Every helper installed by the repository.
for name in \
  sane-app-theme sane-colors sane-doctor sane-firefox-status sane-firefox-sync \
  sane-help sane-image sane-image-status sane-image-theme sane-live-theme sane-menu sane-menu-text \
  sane-mode sane-palette sane-shot-area sane-shot-full sane-system-check sane-thunar-icons sane-thunar-style sane-wallpaper
 do restore_root "/usr/local/bin/$name"; done

echo '[4/4] finished'
cat <<EOF
The last pre-install configuration was restored from:
  $B

Packages installed by the rice were intentionally left installed.
Display-manager services were also left enabled to avoid leaving the machine
without a graphical login. Disable/remove them manually if desired.
EOF
