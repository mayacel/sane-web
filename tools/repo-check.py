#!/usr/bin/env python3
from pathlib import Path
import hashlib, re, sys

root=Path(__file__).resolve().parents[1]
errors=[]

def require(cond,msg):
    if not cond: errors.append(msg)

for rel in (
    'install.sh','update.sh','uninstall.sh','config/dwl/config.h.in',
    'config/dwlb/config.h','lib/semantic.py','lib/firefox_setup.py',
    'firefox/userChrome.css','firefox/userContent.css',
    'assets/wallpapers/sane-current.jpg','assets/wallpapers/garden-kitten.jpg',
    'assets/wallpapers/clouds.jpg',
):
    require((root/rel).exists(),f'missing {rel}')

ch=(root/'firefox/userChrome.css').read_text(errors='ignore')
ct=(root/'firefox/userContent.css').read_text(errors='ignore')
require(ch.count('SANE_FIREFOX_CANONICAL_BEGIN')==1,'Firefox userChrome must have exactly one canonical begin marker')
require(ch.count('SANE_FIREFOX_CANONICAL_END')==1,'Firefox userChrome must have exactly one canonical end marker')
require(ct.count('SANE_FIREFOX_CANONICAL_NEWTAB_BEGIN')==1,'Firefox userContent must have exactly one canonical begin marker')
for legacy in ('SANE_APPS_POLISH_BEGIN','SANE_V6_FIREFOX_BEGIN','SANE_FIREFOX_NATIVE_BEGIN'):
    require(legacy not in ch,f'legacy Firefox marker present: {legacy}')
require('ui.systemUsesDarkTheme' not in (root/'firefox/userChrome.css').read_text(),'ui.systemUsesDarkTheme unexpectedly in CSS')

setup=(root/'lib/firefox_setup.py').read_text()
# Mentioning the stale pref in cleanup code is correct; setting it is not.
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
require('package preflight failed before making package changes' in installer,'installer package preflight missing')

builder=(root/'tools/build-components.sh').read_text()
require('SANE_WLROOTS_ABI' in builder,'build helper lost selected wlroots ABI support')
require('checkout_first "$DWL" 0.9 v0.9' in builder,'build helper no longer selects dwl 0.9 for wlroots 0.20')
require('checkout_first "$DWL" v0.8 0.8' in builder,'build helper no longer retains dwl 0.8 fallback')

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
