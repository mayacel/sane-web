# Architecture

The rice deliberately keeps a short path between source state and what the user
sees.

## Session

```text
SDDM / manual launch
        |
        v
/usr/local/bin/dwl-session
        |
        +-- Wayland/XDG environment
        +-- optional VM cursor workaround
        +-- ~/.config/dwl/environment
        |
        v
dwl -s ~/.config/dwl/start
        |
        +-- portal environment
        +-- sane-palette
        +-- swaybg
        +-- fnott
        +-- polkit agent
        +-- optional output.sh
        +-- dwlb
```

## Dynamic palette

```text
wallpaper
   |
   v
wallust
   |
   v
~/.cache/sane/wallust.env
   |
   v
semantic.py
   |
   +--> ~/.config/sane/colors.env
   +--> foot colors
   +--> fnott colors
   +--> shell prompt
   |
   v
sane-app-theme
   |
   +--> GTK/SaneLiveA|B + XDG light/dark setting
   +--> Thunar CSS
   +--> image viewer background
   +--> zathura/mpv state colors
   |
   v
sane-live-theme
       +--> SIGUSR1 -> dwl border roles
       +--> dwlb socket -> bar roles
       +--> restart fnott
```

The semantic roles are intentionally few:

- `SURFACE`
- `SURFACE_ALT`
- `TEXT`
- `MUTED`
- `BORDER`
- `ACTIVE`
- `ACTIVE_TEXT`
- `SELECT`
- `SELECT_TEXT`
- `URGENT`
- `URGENT_TEXT`

Wallpaper extraction is not allowed to arbitrarily assign every widget a
separate color. The shell owns a coherent role vocabulary.

## Runtime patches

`tools/patch_sources.py` makes three small source changes at build time:

1. dwl's border/focus/urgent arrays become mutable.
2. dwl loads `~/.config/sane/colors.env` and reloads border roles on `SIGUSR1`.
3. dwlb gains one `sane-theme` control-socket command to update its existing
   semantic color roles without restarting dwl.

The patch is kept outside upstream source trees so the repo remains readable:
upstream is cloned, the local config is copied, then the patch is applied.

## Firefox

Firefox is intentionally different from the shell palette files: it has **one**
canonical `userChrome.css` and `userContent.css`. Their colors use Firefox's
system color primitives (`Canvas`, `Field`, `SelectedItem`, `AccentColor`).

`firefox_setup.py` removes all known obsolete Sane blocks before installing the
canonical ones. This is important because older revisions used overlapping
`!important` rules and could keep the browser chrome stuck in a stale theme.

`ui.systemUsesDarkTheme` is explicitly *not* set. GTK/XDG is allowed to report
the current appearance mode.

## Generated versus source-controlled files

Do not edit these as the primary source:

- `~/.config/sane/colors.env`
- `~/.cache/sane/foot-colors.ini`
- `~/.config/fnott/fnott.ini`
- `~/.local/share/themes/SaneLiveA/`
- `~/.local/share/themes/SaneLiveB/`
- generated Thunar block in `~/.config/gtk-3.0/gtk.css`

Edit the corresponding repository script/library instead.
