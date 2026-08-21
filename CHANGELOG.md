# Changelog

## 1.0.2 — 2026-08-20

- Support current Arch repositories where `wlroots0.20` replaces `wlroots0.19`.
- Select the compositor line by installed ABI: dwl 0.9 for wlroots 0.20, dwl 0.8 for wlroots 0.19.
- Prefer wlroots 0.20 while retaining Artix/older-snapshot wlroots 0.19 compatibility.
- Pass the selected ABI to the source build and verify `config.mk` before compiling.
- Add a current dwl GitHub mirror fallback while keeping the archived legacy mirror last.
- Update CI to compile the current Arch/wlroots 0.20 path so repository drift is caught automatically.

## 1.0.1 — 2026-08-20

- Fix installer aborting at package step when `wlroots0.19` is not a valid pacman target on the current repository snapshot but the `wlroots-0.19` ABI is already installed.
- Resolve wlroots by ABI/provider instead of assuming one package name.
- Add package preflight so missing targets are reported before the main pacman transaction.
- Keep locally installed required packages when they are not visible in enabled repositories.
- Verify `pkg-config wlroots-0.19` before compiling dwl v0.8.
- Add an ERR report with failed step, line and command so installer failures no longer silently return to the shell.

## 1.0.0 — 2026-08-20

First repository release of the consolidated rice.

- Arch + Artix/OpenRC installer.
- Source builds for dwl v0.8 and pinned dwlb.
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
