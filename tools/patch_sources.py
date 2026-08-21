#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path

DWL_MARK = "SANE_DYNAMIC_PALETTE_DWL"
DWLB_MARK = "SANE_DYNAMIC_PALETTE_DWLB"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"could not find {label}")
    return text.replace(old, new, 1)


def patch_dwl_config(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    # These three colors must be mutable so the compositor can reload them at runtime.
    for name in ("bordercolor", "focuscolor", "urgentcolor"):
        text, n = re.subn(
            rf"static\s+const\s+float\s+{name}\s*\[\]\s*=",
            f"static float {name}[] =",
            text,
            count=1,
        )
        if n == 0 and not re.search(rf"static\s+float\s+{name}\s*\[\]\s*=", text):
            raise RuntimeError(f"could not find mutable color {name} in {path}")

    # Keep the binding, but make the launcher read the current semantic palette at runtime.
    menucmd_re = re.compile(
        r"static\s+const\s+char\s+\*menucmd\s*\[\]\s*=\s*\{.*?\};",
        re.S,
    )
    replacement = 'static const char *menucmd[] = { "sane-menu", NULL };'
    if menucmd_re.search(text):
        text = menucmd_re.sub(replacement, text, count=1)
    elif replacement not in text:
        raise RuntimeError(f"could not find menucmd in {path}")

    path.write_text(text, encoding="utf-8")


def patch_dwl_c(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if DWL_MARK in text:
        return

    if "#include <string.h>" not in text:
        text = replace_once(text, "#include <stdlib.h>\n", "#include <stdlib.h>\n#include <string.h>\n", "stdlib include")

    anchor = '/* attempt to encapsulate suck into one file */\n#include "client.h"\n'
    if anchor not in text:
        raise RuntimeError(f"could not find client.h include anchor in {path}")

    block = r'''

/* SANE_DYNAMIC_PALETTE_DWL
 * Runtime colors are intentionally tiny state: three semantic border roles.
 * ~/.config/sane/colors.env is generated from the current wallpaper.
 */
static int
sane_parse_hex_color(const char *value, float out[4])
{
    unsigned int rgb;
    const char *p = value;
    size_t len;

    if (!p)
        return 0;
    while (*p == ' ' || *p == '\t')
        p++;
    if (*p == '#')
        p++;
    len = strcspn(p, "\r\n");
    if (len != 6 || sscanf(p, "%06x", &rgb) != 1)
        return 0;

    out[0] = ((rgb >> 16) & 0xff) / 255.0f;
    out[1] = ((rgb >> 8) & 0xff) / 255.0f;
    out[2] = (rgb & 0xff) / 255.0f;
    out[3] = 1.0f;
    return 1;
}

static void
sane_load_colors(void)
{
    char path[4096], line[256];
    const char *home = getenv("HOME");
    FILE *f;
    Client *c;
    struct wlr_surface *focused = seat ? seat->keyboard_state.focused_surface : NULL;

    if (!home)
        return;
    if (snprintf(path, sizeof path, "%s/.config/sane/colors.env", home) >= (int)sizeof path)
        return;
    if (!(f = fopen(path, "r")))
        return;

    while (fgets(line, sizeof line, f)) {
        char *eq = strchr(line, '=');
        if (!eq)
            continue;
        *eq++ = '\0';
        if (!strcmp(line, "BORDER"))
            sane_parse_hex_color(eq, bordercolor);
        else if (!strcmp(line, "ACTIVE"))
            sane_parse_hex_color(eq, focuscolor);
        else if (!strcmp(line, "URGENT"))
            sane_parse_hex_color(eq, urgentcolor);
    }
    fclose(f);

    /* Existing windows update immediately; no compositor restart is needed. */
    wl_list_for_each(c, &clients, link) {
        if (c->isurgent)
            client_set_border_color(c, urgentcolor);
        else if (focused && client_surface(c) == focused)
            client_set_border_color(c, focuscolor);
        else
            client_set_border_color(c, bordercolor);
    }
}

static int
sane_theme_signal(int signal_number, void *data)
{
    (void)signal_number;
    (void)data;
    sane_load_colors();
    return 0;
}
'''
    text = text.replace(anchor, anchor + block, 1)

    # Load persisted colors before the first clients are created.
    init_anchor = "\twl_list_init(&clients);\n\twl_list_init(&fstack);\n"
    if init_anchor not in text:
        # tolerate spaces rather than tabs
        m = re.search(r"\s*wl_list_init\(&clients\);\s*\n\s*wl_list_init\(&fstack\);\s*\n", text)
        if not m:
            raise RuntimeError(f"could not find client list initialization in {path}")
        original = m.group(0)
        text = text[:m.start()] + original + "\tsane_load_colors();\n" + text[m.end():]
    else:
        text = text.replace(init_anchor, init_anchor + "\tsane_load_colors();\n", 1)

    # libwayland handles SIGUSR1 inside the event loop, keeping the reload signal safe.
    dpy_anchor = "\tdpy = wl_display_create();\n"
    if dpy_anchor not in text:
        raise RuntimeError(f"could not find wl_display_create in {path}")
    text = text.replace(
        dpy_anchor,
        dpy_anchor
        + "\tif (!wl_event_loop_add_signal(wl_display_get_event_loop(dpy), SIGUSR1, sane_theme_signal, NULL))\n"
        + '\t\tdie("could not register Sane palette signal");\n',
        1,
    )

    path.write_text(text, encoding="utf-8")


def patch_dwlb_c(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if DWLB_MARK in text:
        return

    needle = '\tif (!strcmp(wordbeg, "status")) {\n'
    if needle not in text:
        raise RuntimeError(f"could not find dwlb status command parser in {path}")

    block = r'''	/* SANE_DYNAMIC_PALETTE_DWLB
	 * Ten RGBA colors map directly onto dwlb's existing semantic roles.
	 * This is a control-socket command, not compositor IPC.
	 */
	if (!strcmp(wordbeg, "sane-theme")) {
		char af[9], ab[9], of[9], ob[9], inf[9], inb[9], uf[9], ub[9], mb[9], mbs[9];
		if (sscanf(wordend, "%8s %8s %8s %8s %8s %8s %8s %8s %8s %8s",
				af, ab, of, ob, inf, inb, uf, ub, mb, mbs) != 10)
			return;
		if (parse_color(af, &active_fg_color) || parse_color(ab, &active_bg_color)
				|| parse_color(of, &occupied_fg_color) || parse_color(ob, &occupied_bg_color)
				|| parse_color(inf, &inactive_fg_color) || parse_color(inb, &inactive_bg_color)
				|| parse_color(uf, &urgent_fg_color) || parse_color(ub, &urgent_bg_color)
				|| parse_color(mb, &middle_bg_color) || parse_color(mbs, &middle_bg_color_selected))
			return;
		wl_list_for_each(it, &bar_list, link)
			it->redraw = true;
		return;
	} else if (!strcmp(wordbeg, "status")) {
'''
    text = text.replace(needle, block, 1)
    path.write_text(text, encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dwl", type=Path, default=Path.home() / "src" / "dwl")
    ap.add_argument("--dwlb", type=Path, default=Path.home() / "src" / "dwlb")
    args = ap.parse_args()

    patch_dwl_config(args.dwl / "config.h")
    patch_dwl_c(args.dwl / "dwl.c")
    patch_dwlb_c(args.dwlb / "dwlb.c")
    print("patched dwl config.h, dwl.c and dwlb.c")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
