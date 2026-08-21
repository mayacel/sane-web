# Troubleshooting

Start with:

```bash
sane-doctor
```

## dwl session exits immediately

Inspect:

```bash
cat ~/.local/state/dwl/start.log
```

Also try from a TTY:

```bash
/usr/local/bin/dwl-session
```

## Invisible cursor in VirtualBox / VMware

The session wrapper detects common virtual GPUs and exports the wlroots
software-cursor workaround. If detection misses your VM, create:

```bash
mkdir -p ~/.config/dwl
cat > ~/.config/dwl/environment <<'EOF'
export WLR_NO_HARDWARE_CURSORS=1
EOF
```

Then start a new dwl session.

## Resolution is wrong

```bash
wlr-randr
cp ~/.config/dwl/output.sh.example ~/.config/dwl/output.sh
chmod +x ~/.config/dwl/output.sh
$EDITOR ~/.config/dwl/output.sh
```

## Firefox does not follow light/dark

Run:

```bash
sane-firefox-status
```

Check the active profile contains only the canonical Sane markers:

```bash
grep -Rni 'SANE_' ~/.config/mozilla/firefox ~/.mozilla/firefox 2>/dev/null
```

There should not be stacked old markers such as:

```text
SANE_APPS_POLISH_BEGIN
SANE_V6_FIREFOX_BEGIN
SANE_FIREFOX_NATIVE_BEGIN
```

Reapply the canonical profile configuration with Firefox closed:

```bash
pkill -TERM -x firefox
sleep 2
python3 /usr/local/lib/sane-rice/firefox_setup.py apply /usr/local/share/sane-rice/firefox
```

Do not add `ui.systemUsesDarkTheme` to `user.js`; the system/portal should own
that state.

## Thunar side icons are invisible on light backgrounds

```bash
sane-mode light
sane-thunar-icons
thunar -q
```

The light mode prefers `breeze`; dark prefers `breeze-dark` when available.

## Images do not open from Thunar

```bash
sane-image-status
xdg-mime query default image/png
sane-image --self-test
```

Expected PNG association:

```text
sane-image.desktop
```

Test a file directly:

```bash
sane-image ~/Pictures/example.png
```

## Wallpaper changes but shell colors do not

```bash
sane-colors
sane-palette "$(cat ~/.config/dwl/wallpaper)"
```

If wallust is missing:

```bash
wallust --version
```

Then rerun `./install.sh` from the repository.

## Artix graphical login

Check OpenRC services:

```bash
rc-status -a | grep -E 'dbus|elogind|sddm'
```

The session file should exist:

```bash
cat /usr/share/wayland-sessions/sane-dwl.desktop
```
