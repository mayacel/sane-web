#!/usr/bin/env python3
from __future__ import annotations
import configparser, os, re, sys
from pathlib import Path

CHROME_BLOCKS=[
("/* SANE_FIREFOX_NATIVE_BEGIN */","/* SANE_FIREFOX_NATIVE_END */"),
("/* SANE_V6_FIREFOX_BEGIN */","/* SANE_V6_FIREFOX_END */"),
("/* SANE_APPS_POLISH_BEGIN */","/* SANE_APPS_POLISH_END */"),
("/* SANE_FIREFOX_CANONICAL_BEGIN */","/* SANE_FIREFOX_CANONICAL_END */"),
]
CONTENT_BLOCKS=[
("/* SANE_FIREFOX_NEWTAB_BEGIN */","/* SANE_FIREFOX_NEWTAB_END */"),
("/* SANE_V6_NEWTAB_BEGIN */","/* SANE_V6_NEWTAB_END */"),
("/* SANE_APPS_POLISH_NEWTAB_BEGIN */","/* SANE_APPS_POLISH_NEWTAB_END */"),
("/* SANE_FIREFOX_CANONICAL_NEWTAB_BEGIN */","/* SANE_FIREFOX_CANONICAL_NEWTAB_END */"),
]
PREFS={
 "toolkit.legacyUserProfileCustomizations.stylesheets":"true",
 "extensions.activeThemeID":'"default-theme@mozilla.org"',
 "browser.theme.native-theme":"true",
 "browser.theme.toolbar-theme":"2",
 "browser.theme.content-theme":"2",
 "widget.use-xdg-desktop-portal.settings":"1",
 "browser.compactmode.show":"true",
 "browser.uidensity":"1",
 "browser.aboutwelcome.enabled":"false",
 "browser.newtabpage.activity-stream.showSearch":"false",
 "browser.newtabpage.activity-stream.feeds.topsites":"false",
 "browser.newtabpage.activity-stream.showSponsoredTopSites":"false",
 "browser.newtabpage.activity-stream.showSponsored":"false",
 "browser.newtabpage.activity-stream.feeds.section.topstories":"false",
 "browser.newtabpage.activity-stream.feeds.system.topstories":"false",
 "browser.newtabpage.activity-stream.feeds.section.highlights":"false",
 "browser.newtabpage.activity-stream.showWeather":"false",
 "browser.toolbars.bookmarks.visibility":'"never"',
}
CONFLICT={"ui.systemUsesDarkTheme","browser.theme.toolbar-theme","browser.theme.content-theme","extensions.activeThemeID","browser.theme.native-theme","widget.use-xdg-desktop-portal.settings"}

def roots():
 h=Path.home(); out=[h/'.config/mozilla/firefox',h/'.mozilla/firefox']; x=os.environ.get('XDG_CONFIG_HOME')
 if x: out.insert(0,Path(x)/'mozilla/firefox')
 return out

def discover():
 found=[]
 for root in roots():
  if not root.exists(): continue
  for marker in ('prefs.js','places.sqlite','compatibility.ini'):
   for f in root.glob(f'**/{marker}'):
    if f.parent not in found: found.append(f.parent)
 return found

def strip_blocks(text,blocks):
 for b,e in blocks: text=re.sub(re.escape(b)+r'.*?'+re.escape(e)+r'\s*','',text,flags=re.S)
 text=re.sub(r'^[ \t]*@import\s+url\(["\']?sane-colors\.css["\']?\)\s*;[ \t]*$\n?','',text,flags=re.M|re.I)
 return text

def strip_pref(text,name):
 return re.sub(r'^[ \t]*user_pref\(\s*["\']'+re.escape(name)+r'["\']\s*,.*?\);\s*$','',text,flags=re.M)

def set_pref(text,name,value):
 text=strip_pref(text,name)
 return text.rstrip()+f'\nuser_pref("{name}", {value});\n'

def apply(profile,src):
 ch=profile/'chrome'; ch.mkdir(parents=True,exist_ok=True)
 uc=ch/'userChrome.css'; old=uc.read_text(errors='ignore') if uc.exists() else ''
 uc.write_text(strip_blocks(old,CHROME_BLOCKS).rstrip()+'\n\n'+(src/'userChrome.css').read_text()+'\n')
 cnt=ch/'userContent.css'; old=cnt.read_text(errors='ignore') if cnt.exists() else ''
 cnt.write_text(strip_blocks(old,CONTENT_BLOCKS).rstrip()+'\n\n'+(src/'userContent.css').read_text()+'\n')
 stale=ch/'sane-colors.css'
 if stale.exists():
  disabled=ch/'sane-colors.css.disabled-sane-rice'
  if disabled.exists(): disabled.unlink()
  stale.rename(disabled)
 user=profile/'user.js'; txt=user.read_text(errors='ignore') if user.exists() else ''
 # remove old marked Sane prefs wholesale
 for b,e in [('// SANE_V6_PREFS_BEGIN','// SANE_V6_PREFS_END'),('// SANE_APPS_POLISH_BEGIN','// SANE_APPS_POLISH_END'),('// SANE_FIREFOX_SYSTEM_PREFS_BEGIN','// SANE_FIREFOX_SYSTEM_PREFS_END')]:
  txt=re.sub(re.escape(b)+r'.*?'+re.escape(e)+r'\s*','',txt,flags=re.S)
 for k in PREFS: txt=strip_pref(txt,k)
 txt=strip_pref(txt,'ui.systemUsesDarkTheme')
 txt=txt.rstrip()+'\n\n// SANE_FIREFOX_SYSTEM_PREFS_BEGIN\n'
 for k,v in PREFS.items(): txt+=f'user_pref("{k}", {v});\n'
 txt+='// SANE_FIREFOX_SYSTEM_PREFS_END\n'
 user.write_text(txt)
 prefs=profile/'prefs.js'
 if prefs.exists():
  ptxt=prefs.read_text(errors='ignore')
  ptxt=strip_pref(ptxt,'ui.systemUsesDarkTheme')
  for k in ('browser.theme.toolbar-theme','browser.theme.content-theme'): ptxt=strip_pref(ptxt,k)
  prefs.write_text(ptxt)

def main():
 if len(sys.argv)<3 or sys.argv[1] not in ('apply','status'):
  print('usage: firefox_setup.py apply FIREFOX_ASSETS | status FIREFOX_ASSETS'); return 2
 profs=discover(); src=Path(sys.argv[2])
 if sys.argv[1]=='apply':
  if not profs: print('No Firefox profile found.',file=sys.stderr); return 1
  for p in profs: apply(p,src); print(p)
 else:
  print('profiles found:',len(profs))
  for p in profs:
   print('profile:',p)
   for rel,mark in [('chrome/userChrome.css','SANE_FIREFOX_CANONICAL_BEGIN'),('chrome/userContent.css','SANE_FIREFOX_CANONICAL_NEWTAB_BEGIN'),('user.js','SANE_FIREFOX_SYSTEM_PREFS_BEGIN')]:
    f=p/rel; print(f'  {rel}:', 'yes' if f.exists() and mark in f.read_text(errors='ignore') else 'NO')
 return 0
if __name__=='__main__': raise SystemExit(main())
