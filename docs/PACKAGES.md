# Package roles

The installer intentionally uses repository packages for ordinary applications
and compiles only the small pieces whose source/config integration is part of
the rice.

## Compiled by the installer

- **dwl v0.8** — local `config.h` plus the runtime semantic-border patch.
- **dwlb** — pinned revision plus the runtime `sane-theme` socket command.
- **wallust** — installed from crates.io only when no `wallust` binary already
  exists.

## Installed through pacman

### Build / Wayland

`base-devel`, `git`, `pkgconf`, `python`, `rust`, `libinput`,
`wayland`, `wayland-protocols`, `libxkbcommon`, `libxcb`, `xcb-util-wm`,
`xorg-xwayland`, `fcft`, `pixman`.

### wlroots 0.19 provider

`dwl v0.8` links against the pkg-config ABI `wlroots-0.19`. The installer first
uses an already available ABI, otherwise it resolves a repository provider
(`wlroots0.19`, or `wlroots` only when that package is actually version 0.19).
This avoids tying Arch/Artix support to one pacman package name.

### Shell

`foot`, `terminus-font`, `wmenu`, `fnott`, `swaybg`, `wlr-randr`, `grim`,
`slurp`, `wl-clipboard`, `libnotify`.

### Applications

`thunar`, `tumbler`, `ffmpegthumbnailer`, `thunar-archive-plugin`,
`file-roller`, `gvfs`, `udisks2`, `firefox`, `imv`, `mpv`, `zathura`,
`zathura-pdf-mupdf`.

### Integration

`xdg-utils`, `xdg-user-dirs`, `xdg-desktop-portal`,
`xdg-desktop-portal-gtk`, `desktop-file-utils`, `shared-mime-info`,
`gsettings-desktop-schemas`, `dconf`, `gtk3`, `adwaita-icon-theme`,
`breeze-icons`, `polkit`, `polkit-gnome`.

Artix additionally gets its OpenRC `dbus`/`elogind` service packages.
