# Customization

## Keyboard layout

The xkb layout is compile-time dwl configuration.

```bash
SANE_KEYBOARD_LAYOUT=us ./install.sh
```

Default: `br`.

## Key bindings

Edit:

```text
config/dwl/config.h.in
```

Then rebuild/reinstall:

```bash
./update.sh
```

The file contains `@KEYBOARD_LAYOUT@`; do not remove that placeholder unless you
also change `tools/build-components.sh`.

## Monitor/output settings

Never hardcode a monitor name into the shared repository. Use the per-machine
file:

```bash
cp ~/.config/dwl/output.sh.example ~/.config/dwl/output.sh
chmod +x ~/.config/dwl/output.sh
wlr-randr
$EDITOR ~/.config/dwl/output.sh
```

Example:

```sh
wlr-randr --output eDP-1 --mode 1920x1080@60Hz --scale 1
```

## Wallpaper

Place images in:

```text
~/Pictures/wallpapers/
```

Then use `Super+W` or:

```bash
sane-wallpaper
```

The selected path is stored in:

```text
~/.config/dwl/wallpaper
```

## Palette behavior

Source of truth:

```text
lib/semantic.py
```

Do not edit `~/.config/sane/colors.env` and expect it to survive the next
wallpaper/mode change.

Current behavior:

- light surface: high-luminance wallpaper tint;
- dark surface: muted wallpaper hue at a dark-but-colored luminance;
- accents: saturated wallpaper candidates normalized for readability;
- selection: derived from surface + active, not a separate random color.

## Firefox

Source files:

```text
firefox/userChrome.css
firefox/userContent.css
lib/firefox_setup.py
```

Keep exactly one canonical Sane block. Do not copy old userChrome experiments
back into the profile; the installer intentionally removes known old markers.

## Thunar

Structure:

```text
lib/thunar_layout.py
```

Style:

```text
bin/sane-thunar-style
bin/sane-thunar-icons
```

The left side pane is hidden by default. `Ctrl+B` toggles it.

## Machine-specific environment

Use:

```text
~/.config/dwl/environment
```

rather than modifying `/usr/local/bin/dwl-session` directly.
