#!/usr/bin/env python3
from __future__ import annotations
import colorsys, os, re, sys
from pathlib import Path

HEX_RE = re.compile(r"#?([0-9a-fA-F]{6})(?:[0-9a-fA-F]{2})?$")

def parse_hex(value):
    value=value.strip().strip('"').strip("'")
    m=HEX_RE.fullmatch(value)
    if not m:
        raise ValueError(value)
    h=m.group(1)
    return tuple(int(h[i:i+2],16) for i in (0,2,4))

def hx(rgb): return "%02x%02x%02x" % rgb
def rgb_to_hls(rgb): return colorsys.rgb_to_hls(*(v/255.0 for v in rgb))
def hls_to_rgb(h,l,s): return tuple(round(v*255) for v in colorsys.hls_to_rgb(h,l,s))
def sch(v):
    c=v/255.0
    return c/12.92 if c<=0.04045 else ((c+0.055)/1.055)**2.4
def luminance(rgb):
    r,g,b=map(sch,rgb); return .2126*r+.7152*g+.0722*b
def contrast(a,b):
    l1,l2=luminance(a),luminance(b); hi,lo=max(l1,l2),min(l1,l2)
    return (hi+.05)/(lo+.05)
def mix(a,b,t):
    return tuple(round(x*(1-t)+y*t) for x,y in zip(a,b))
def saturation(rgb): return rgb_to_hls(rgb)[2]
def hue(rgb): return rgb_to_hls(rgb)[0]*360.0
def hdist(a,b):
    d=abs(a-b)%360.0; return min(d,360.0-d)

def force_surface(seed, mode):
    h,_,s=rgb_to_hls(seed)
    if s<.025: h=0.0

    # LIGHT is intentionally unchanged from v2.0.0.
    if mode=="light":
        s=min(s,.16)
        return hls_to_rgb(h,.90,s)

    # DARK returns to a muted wallpaper-tinted charcoal rather than near-black.
    # Keep real wallpaper hue, but bound it so the shell stays coherent.
    s=min(s,.28)
    return hls_to_rgb(h,.27,s)

def force_text(surface, mode):
    h,_,s=rgb_to_hls(surface)
    if mode=="light":
        c=hls_to_rgb(h,.09,min(s,.08)); fallback=(22,22,19)
    else:
        c=hls_to_rgb(h,.90,min(s,.07)); fallback=(239,238,230)
    return c if contrast(surface,c)>=7 else fallback

def normalize_accent(c, mode):
    h,_,s=rgb_to_hls(c)
    s=max(.35,min(s,.72))
    return hls_to_rgb(h,.38 if mode=="light" else .62,s)

def readable_text(bg, preferred):
    if contrast(bg,preferred)>=4.5: return preferred
    dark=(20,20,18); light=(248,247,240)
    return dark if contrast(bg,dark)>=contrast(bg,light) else light

def choose_accent(surface, colors, mode):
    best=None; best_score=-999
    for raw in colors:
        sat=saturation(raw)
        if sat<.12: continue
        c=normalize_accent(raw,mode)
        penalty=max(0.0,(50-min(hdist(hue(raw),8),hdist(hue(raw),28)))/50)*1.2
        score=sat*4+min(contrast(surface,c),8)*.35-penalty
        if score>best_score: best,best_score=c,score
    return best or ((82,103,60) if mode=="light" else (164,190,124))

def choose_urgent(surface, colors, accent, mode):
    best=None; best_score=-999
    for raw in colors:
        c=normalize_accent(raw,mode)
        dist=min(hdist(hue(raw),5),hdist(hue(raw),24))
        score=saturation(raw)*4+min(contrast(surface,c),8)*.25-dist/35
        if score>best_score: best,best_score=c,score
    if best is None or best_score<.3:
        return (151,67,46) if mode=="light" else (211,111,81)
    return best

def parse_raw(path):
    out={}
    for line in Path(path).read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            k,v=line.split("=",1); out[k.strip().upper()]=v.strip().strip('"').strip("'")
    return out

def main():
    if len(sys.argv)!=2:
        print("usage: semantic.py RAW_ENV",file=sys.stderr); return 2
    raw=parse_raw(sys.argv[1])
    req=["BACKGROUND","FOREGROUND"]+[f"COLOR{i}" for i in range(16)]
    miss=[k for k in req if k not in raw]
    if miss:
        print("missing: "+", ".join(miss),file=sys.stderr); return 1

    modefile=Path.home()/".config/sane/mode"
    mode=modefile.read_text().strip() if modefile.exists() else "light"
    if mode not in ("light","dark"): mode="light"

    raw_bg=parse_hex(raw["BACKGROUND"])
    ansi=[parse_hex(raw[f"COLOR{i}"]) for i in range(16)]
    surface=force_surface(raw_bg,mode)
    text=force_text(surface,mode)
    candidates=[ansi[i] for i in (1,2,3,4,5,6,9,10,11,12,13,14)]
    active=choose_accent(surface,candidates,mode)
    urgent=choose_urgent(surface,candidates,active,mode)

    env={
        "MODE":mode,
        "SURFACE":hx(surface),
        "SURFACE_ALT":hx(mix(surface,text,.045 if mode=="light" else .07)),
        "TEXT":hx(text),
        "MUTED":hx(mix(surface,text,.58 if mode=="light" else .62)),
        "BORDER":hx(mix(surface,text,.28 if mode=="light" else .34)),
        "ACTIVE":hx(active),
        "ACTIVE_TEXT":hx(readable_text(active,text)),
        "SELECT":hx(mix(surface,active,.18 if mode=="light" else .22)),
        "SELECT_TEXT":hx(text),
        "URGENT":hx(urgent),
        "URGENT_TEXT":hx(readable_text(urgent,text)),
    }
    for i,c in enumerate(ansi): env[f"COLOR{i}"]=hx(c)

    home=Path.home(); cfg=home/".config/sane"; cache=home/".cache/sane"; fn=home/".config/fnott"
    cfg.mkdir(parents=True,exist_ok=True); cache.mkdir(parents=True,exist_ok=True); fn.mkdir(parents=True,exist_ok=True)
    tmp=cfg/"colors.tmp"
    tmp.write_text("".join(f"{k}={v}\n" for k,v in env.items()))
    os.replace(tmp,cfg/"colors.env")

    body=(f"background={env['SURFACE']}\nforeground={env['TEXT']}\n"
          f"cursor={env['SURFACE']} {env['ACTIVE']}\n"
          f"selection-foreground={env['SELECT_TEXT']}\nselection-background={env['SELECT']}\n"
          f"urls={env['ACTIVE']}\n"
          +"".join(f"regular{i}={env[f'COLOR{i}']}\n" for i in range(8))
          +"".join(f"bright{i-8}={env[f'COLOR{i}']}\n" for i in range(8,16)))
    (cache/"foot-colors.ini").write_text("[colors-light]\n"+body+"\n[colors-dark]\n"+body)

    (fn/"fnott.ini").write_text(
        "# Generated by sane-palette v2\n"
        "anchor=top-right\nstacking-order=bottom-up\nedge-margin-vertical=7\nedge-margin-horizontal=7\n"
        "notification-margin=5\nmin-width=220\nmax-width=360\nmax-height=0\nmax-icon-size=0\n"
        f"background={env['SURFACE']}ff\nborder-color={env['ACTIVE']}ff\nborder-size=1\nborder-radius=0\n"
        "padding-vertical=6\npadding-horizontal=8\ndpi-aware=no\n"
        "title-font=Terminus:size=10\n"+f"title-color={env['MUTED']}ff\n"+"title-format=<i>%a%A</i>\n"
        "summary-font=Terminus:size=10\n"+f"summary-color={env['TEXT']}ff\n"+"summary-format=<b>%s\\n</b>\n"
        "body-font=Terminus:size=10\n"+f"body-color={env['TEXT']}ff\n"+"body-format=%b\n"
        "progress-bar-height=2\n"+f"progress-color={env['ACTIVE']}ff\n"+"progress-style=bar\n"
        "default-timeout=5\nmax-timeout=10\nidle-timeout=0\n\n"
        "[low]\n"+f"background={env['SURFACE']}ff\nborder-color={env['BORDER']}ff\n"
        +f"title-color={env['MUTED']}ff\nsummary-color={env['MUTED']}ff\nbody-color={env['MUTED']}ff\n\n"
        "[normal]\n"+f"background={env['SURFACE']}ff\nborder-color={env['ACTIVE']}ff\n"
        +f"title-color={env['MUTED']}ff\nsummary-color={env['TEXT']}ff\nbody-color={env['TEXT']}ff\n\n"
        "[critical]\n"+f"background={env['URGENT']}ff\nborder-color={env['URGENT_TEXT']}ff\n"
        +f"title-color={env['URGENT_TEXT']}ff\nsummary-color={env['URGENT_TEXT']}ff\nbody-color={env['URGENT_TEXT']}ff\n"
    )
    r,g,b=active
    (cfg/"prompt.sh").write_text(f"PS1='\\[\\e[38;2;{r};{g};{b}m\\]based\\[\\e[0m\\]% '\n")
    print(f"mode={mode} surface=#{env['SURFACE']} text=#{env['TEXT']} active=#{env['ACTIVE']} select=#{env['SELECT']} urgent=#{env['URGENT']} contrast={contrast(surface,text):.1f}:1")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
