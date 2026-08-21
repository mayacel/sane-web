#!/usr/bin/env python3
from pathlib import Path
import hashlib, os, re, sys

root=Path(__file__).resolve().parents[1]
errors=[]

def require(cond,msg):
    if not cond: errors.append(msg)

for rel in (
    'install.sh','update.sh','uninstall.sh','config/dwl/config.h.in',
    'config/dwlb/config.h','lib/semantic.py','lib/firefox_setup.py',
    'firefox/userChrome.css','firefox/userContent.css',
    'assets/wallpapers/sane-current.jpg','assets/wallpapers/garden-kitten.jpg',
    'assets/wallpapers/clouds.jpg','tools/system-safety.sh','bin/sane-system-check',
):
    require((root/rel).exists(),f'missing {rel}')

for rel in ('install.sh','update.sh','uninstall.sh','tools/build-components.sh'):
    p=root/rel
    require(p.exists() and os.access(p, os.X_OK), f'{rel} is not executable in the checkout')

ch=(root/'firefox/userChrome.css').read_text(errors='ignore')
ct=(root/'firefox/userContent.css').read_text(errors='ignore')
require(ch.count('SANE_FIREFOX_CANONICAL_BEGIN')==1,'Firefox userChrome must have exactly one canonical begin marker')
require(ch.count('SANE_FIREFOX_CANONICAL_END')==1,'Firefox userChrome must have exactly one canonical end marker')
require(ct.count('SANE_FIREFOX_CANONICAL_NEWTAB_BEGIN')==1,'Firefox userContent must have exactly one canonical begin marker')
for legacy in ('SANE_APPS_POLISH_BEGIN','SANE_V6_FIREFOX_BEGIN','SANE_FIREFOX_NATIVE_BEGIN'):
    require(legacy not in ch,f'legacy Firefox marker present: {legacy}')
require('ui.systemUsesDarkTheme' not in (root/'firefox/userChrome.css').read_text(),'ui.systemUsesDarkTheme unexpectedly in CSS')

setup=(root/'lib/firefox_setup.py').read_text()
require('user_pref("ui.systemUsesDarkTheme"' not in setup,'firefox_setup.py must never set ui.systemUsesDarkTheme')

dwl=(root/'config/dwl/config.h.in').read_text()
require('@KEYBOARD_LAYOUT@' in dwl,'dwl config lost @KEYBOARD_LAYOUT@ placeholder')
require('TAGCOUNT (5)' in dwl,'dwl config is not the five-tag rice')
require('&layouts[0]' in dwl,'dwl default layout no longer points to tile')

installer=(root/'install.sh').read_text()
require('wlroots0.19 libinput' not in installer,'installer hardcodes a wlroots provider in REQUIRED again')
require('wlroots0.20' in installer and 'wlroots0.19' in installer,'installer must support both current 0.20 and legacy 0.19 providers')
require('SANE_WLROOTS_ABI' in installer,'installer no longer exports selected wlroots ABI')
require('pkg-config --exists "wlroots-$WLR_ABI"' in installer,'installer no longer verifies the selected wlroots ABI')
require('package preflight failed before rice package changes' in installer,'installer package preflight missing')
require(re.search(r'^\s*sudo pacman -Sy\s*$',installer,re.M) is None,'installer must never run isolated pacman -Sy against the live database')
require('sudo pacman -Syu' in installer,'installer no longer performs a complete rolling-release upgrade before new packages')
require('bash "$ROOT/tools/system-safety.sh" preflight' in installer,'installer host preflight missing')
require('bash "$ROOT/tools/system-safety.sh" post-upgrade' in installer,'installer post-upgrade host check missing')
require('bash /usr/local/lib/sane-rice/system-safety.sh post-install' in installer,'installer final fatal host check missing')
require('sudo install -m 0755 "$ROOT/tools/system-safety.sh" /usr/local/lib/sane-rice/system-safety.sh' in installer,'installer no longer installs the host safety checker')
require('sudo systemctl enable sddm.service 2>/dev/null || true' not in installer,'installer must not hide systemctl enable failures')
require('sudo systemctl enable sddm.service' in installer,'installer no longer enables SDDM on systemd')

session_dir='sudo install -d -m 0755 /usr/share/wayland-sessions'
session_file='sudo install -m 0644 "$ROOT/config/sane-dwl.desktop" /usr/share/wayland-sessions/sane-dwl.desktop'
require(session_dir in installer,'installer no longer creates /usr/share/wayland-sessions on minimal systems')
require(session_file in installer,'installer no longer installs the Sane Wayland session entry')
require(installer.find(session_dir) < installer.find(session_file),'Wayland session directory must be created before installing sane-dwl.desktop')

safety=(root/'tools/system-safety.sh').read_text()
for needle,msg in (
    ('systemctl show-environment','host safety check no longer verifies systemd control'),
    ('/run/systemd/private','host safety check no longer verifies the systemd private socket'),
    ('busctl --system','host safety check no longer verifies system D-Bus'),
    ('XDG_RUNTIME_DIR','host safety check no longer verifies XDG_RUNTIME_DIR'),
    ('ip -4 route show default','host safety check no longer verifies a default route'),
    ('getent ahosts archlinux.org','host safety check no longer verifies DNS'),
    ('/usr/lib/modules/$running','host safety check no longer verifies running kernel modules'),
    ('findmnt --fstab','host safety check no longer verifies boot mounts from fstab'),
    ('bootctl --print-esp-path','host safety check no longer verifies the systemd-boot ESP'),
    ('pacman -Ql "$pkg"','host safety check no longer compares installed kernel payloads'),
):
    require(needle in safety,msg)

builder=(root/'tools/build-components.sh').read_text()
require('SANE_WLROOTS_ABI' in builder,'build helper lost selected wlroots ABI support')
require('checkout_first "$DWL" 0.9 v0.9' in builder,'build helper no longer selects dwl 0.9 for wlroots 0.20')
require('checkout_first "$DWL" v0.8 0.8' in builder,'build helper no longer retains dwl 0.8 fallback')
require('48dbe00bdb98a1ae6a0e60558ce14503616aa759' in builder,'dwlb must be pinned to the reachable upstream main commit')
require('d1223810b275309d279070324740515a16f795f3' not in builder,'transient GitHub PR merge SHA must not be used as dwlb pin')
require('checkout_exact "$DWLB" "$DWLB_PIN" dwlb' in builder,'dwlb pin must be verified as a complete checkout before patching')
require('pkg-config --exists tllist' in builder,'build helper no longer preflights tllist')
require('sudo pacman -S --needed tllist' in builder,'build helper no longer self-heals missing Arch tllist')

workflow=(root/'.github/workflows/validate.yml').read_text()
require('fcft pixman tllist' in workflow,'Arch CI must install tllist with fcft/pixman')
require('pkg-config --exists wayland-client wayland-cursor fcft pixman-1 tllist' in workflow,'Arch CI no longer verifies dwlb pkg-config closure')
require('for f in tools/*.sh' in workflow,'CI no longer syntax-checks every shell tool, including system-safety.sh')

semantic=(root/'lib/semantic.py').read_text()
require('return hls_to_rgb(h,.90,s)' in semantic,'light surface regression')
require('return hls_to_rgb(h,.27,s)' in semantic,'dark tinted-surface regression')

sums=root/'assets/wallpapers/SHA256SUMS'
if sums.exists():
    for line in sums.read_text().splitlines():
        digest,name=line.split(None,1); name=name.strip().lstrip('*')
        p=root/'assets/wallpapers'/name
        if p.exists():
            actual=hashlib.sha256(p.read_bytes()).hexdigest()
            require(actual==digest,f'wallpaper checksum mismatch: {name}')

if errors:
    for e in errors: print('ERROR:',e,file=sys.stderr)
    raise SystemExit(1)
print('repository checks OK')
