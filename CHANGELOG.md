# Changelog

## 1.0.7 — 2026-08-21

- Remove the isolated live `pacman -Sy` refresh from the installer. The default rolling-release update now happens as a complete `pacman -Syu` transaction before rice package installation.
- Add a fatal host preflight before package changes. On Arch it verifies systemd PID 1/control access, `/run/systemd/private`, system D-Bus, the real `XDG_RUNTIME_DIR`, network route/DNS, running-kernel modules and configured boot/EFI mounts.
- Re-check the host immediately after the full system upgrade so a systemd/D-Bus/network regression stops the installer before desktop configuration continues.
- Validate standard installed kernel payloads against `/usr/lib/modules` and `/boot/vmlinuz-*`, and verify a detected systemd-boot ESP is actually mounted.
- Refuse `SANE_FULL_UPGRADE=0` when the currently synchronized pacman databases already report pending upgrades.
- Stop hiding `systemctl enable sddm.service` failures; a broken system manager can no longer be silently treated as successful installation.
- Add a final fatal host check before the installer prints `finished`.
- Add the installed `sane-system-check` diagnostic command for repeating the host checks later.
- Expand repository invariants and CI shell syntax checks so isolated `pacman -Sy`, hidden SDDM systemctl failures, or removal of the new safety checks are caught automatically.

## 1.0.6 — 2026-08-20

- Fix step 9/12 failing on minimal Arch installations where `/usr/share/wayland-sessions` does not exist yet.
- Resolve display-manager installation first, then explicitly create `/usr/share/wayland-sessions` before installing `sane-dwl.desktop`.
- Keep the session-entry installation valid even when `SANE_INSTALL_SDDM=no` and no display manager package is present to create the directory as a side effect.
- Verify that the installed Wayland session file is readable before continuing.

## 1.0.5 — 2026-08-20

- Fix fresh Arch builds of dwlb failing with `Package tllist ... not found` followed by the misleading `pixman.h: No such file or directory` error.
- Detect the missing `tllist.pc` build dependency before compiling dwlb and install the official `tllist` package automatically when available.
- Verify the complete dwlb pkg-config dependency closure (`wayland-client`, `wayland-cursor`, `fcft`, `pixman-1`, `tllist`) before invoking `make`.
- Update the Arch CI smoke build to install `tllist` and explicitly test the pkg-config closure so this fresh-install regression is caught automatically.

## 1.0.4 — 2026-08-20

- Fix step 4/12 failing after cloning dwlb with `fatal: unable to read tree`.
- Replace the transient GitHub PR test-merge SHA `d1223810...` with the reachable upstream `main` commit `48dbe00b...`.
- Verify the pinned dwlb commit and its complete tree before patching/building.
- Add an explicit fetch fallback for a configured `SANE_DWLB_REF` when its commit is not already present in the normal clone.
- Add repository invariants that reject the transient PR merge SHA in future releases.

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
