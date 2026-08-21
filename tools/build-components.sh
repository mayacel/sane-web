#!/bin/bash
set -euo pipefail
ROOT="${1:?repo root required}"
BUILD_ROOT="${SANE_BUILD_ROOT:-$HOME/.cache/sane-rice/build}"
JOBS="${SANE_JOBS:-$(nproc 2>/dev/null || echo 2)}"
mkdir -p "$BUILD_ROOT"

clone_repo() {
  local dest="$1"; shift
  rm -rf "$dest"
  for url in "$@"; do
    echo "==> cloning $url"
    if git clone "$url" "$dest"; then return 0; fi
    rm -rf "$dest"
  done
  return 1
}

# This config targets dwl v0.8/wlroots 0.19.
DWL="$BUILD_ROOT/dwl"
clone_repo "$DWL" \
  https://codeberg.org/dwl/dwl.git \
  https://github.com/djpohly/dwl.git || { echo 'Could not clone dwl.' >&2; exit 1; }
(
  cd "$DWL"
  git checkout v0.8 2>/dev/null || git checkout 0.8 2>/dev/null || {
    echo 'Could not find dwl v0.8/0.8 tag or branch.' >&2
    exit 1
  }
)
sed "s/@KEYBOARD_LAYOUT@/${SANE_KEYBOARD_LAYOUT:-br}/g" "$ROOT/config/dwl/config.h.in" > "$DWL/config.h"
# Make's last assignment wins. Appending avoids depending on the exact comment
# placement used by the v0.8 config.mk while keeping upstream untouched.
printf '\n# Sane rice: XWayland enabled\nXWAYLAND = -DXWAYLAND\nXLIBS = xcb xcb-icccm\n' >> "$DWL/config.mk"

# Pin dwlb because patch_sources.py adds a runtime sane-theme command to its parser.
DWLB="$BUILD_ROOT/dwlb"
clone_repo "$DWLB" https://github.com/kolunmi/dwlb.git || { echo 'Could not clone dwlb.' >&2; exit 1; }
git -C "$DWLB" checkout d1223810b275309d279070324740515a16f795f3
cp "$ROOT/config/dwlb/config.h" "$DWLB/config.h"

python3 "$ROOT/tools/patch_sources.py" --dwl "$DWL" --dwlb "$DWLB"

make -C "$DWL" clean >/dev/null 2>&1 || true
make -C "$DWL" -j"$JOBS"
make -C "$DWLB" clean >/dev/null 2>&1 || true
make -C "$DWLB" -j"$JOBS"

if [ "${SANE_BUILD_ONLY:-0}" = 1 ]; then
  echo '==> build-only requested; skipping install'
else
  sudo make -C "$DWL" install
  sudo make -C "$DWLB" install
  echo '==> built and installed dwl + dwlb'
fi
