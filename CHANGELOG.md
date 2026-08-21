# Changelog

## 1.0.3 — 2026-08-20

- Fix fresh clones failing at step 4/12 with `tools/build-components.sh: Permission denied`.
- Preserve executable bits for `install.sh`, `update.sh`, `uninstall.sh` and `tools/build-components.sh` in Git.
- Fresh clones can run the installer/build helper without a manual `chmod` workaround.

## 1.0.2 — 2026-08-20

- Support current Arch Linux repositories where `wlroots0.20` replaces `wlroots0.19`.
- Detect supported wlroots ABI in this order: installed `wlroots-0.20`, installed `wlroots-0.19`, repository `wlroots0.20`, repository `wlroots0.19`, then version-compatible `wlroots`.
- Select dwl 0.9 for wlroots 0.20 and dwl 0.8 for wlroots 0.19.
- Keep the same Sane config and dynamic-palette source patch across the selected dwl line.
- Update the Arch CI smoke build to compile against `wlroots0.20`.
- Preserve Artix/older-repository compatibility through the existing 0.19 path.

## 1.0.1 — 2026-08-20

- Fix installer aborting at package step when `wlroots0.19` is not a valid pacman target on the current repository snapshot but the `wlroots-0.19` ABI is already installed.
- Resolve wlroots by ABI/provider instead of assuming one package name.
- Add package preflight so missing targets are reported before the main pacman transaction.
- Keep locally installed required packages when they are not visible in enabled repositories.
- Verify a supported wlroots pkg-config ABI before compiling dwl.
- Add an ERR report with failed step, line and command so installer failures no longer silently return to the shell.

## 1.0.0 — 2026-08-20

First repository release of the consolidated rice.

- Arch + Artix/OpenRC installer.
- Source builds for dwl and pinned dwlb.
- Dynamic wallpaper-derived semantic light/dark palette.
- Runtime dwl/dwlb border/bar color reload.
- foot, wmenu, fnott and screenshot integration.
- Sane Thunar detailed view and light/dark side-pane icon handling.
- Single-source Firefox System-theme userChrome/userContent setup.
- imv/imv-dir image MIME integration.
- mpv and zathura defaults.
- SDDM session entry and conditional display-manager setup.
- Backup/update/uninstall workflow.
- Three bundled wallpapers.
