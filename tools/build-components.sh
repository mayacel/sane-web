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

checkout_first() {
  local repo="$1"; shift
  local ref
  for ref in "$@"; do
    if git -C "$repo" checkout "$ref" >/dev/null 2>&1; then
      echo "==> selected dwl ref: $ref"
      return 0
    fi
  done
  return 1
}

checkout_exact() {
  local repo="$1" ref="$2" label="$3"

  if ! git -C "$repo" cat-file -e "${ref}^{commit}" 2>/dev/null; then
    echo "==> $label pin $ref is not present in the clone; fetching it explicitly"
    git -C "$repo" fetch --no-tags origin "$ref" >/dev/null 2>&1 || return 1
    ref=FETCH_HEAD
  fi

  git -C "$repo" cat-file -e "${ref}^{tree}" 2>/dev/null || return 1
  git -C "$repo" checkout --detach "$ref" >/dev/null 2>&1 || return 1
  echo "==> selected $label ref: $(git -C "$repo" rev-parse --short=12 HEAD)"
}

ensure_dwlb_build_deps() {
  # Arch's fcft binary package does not pull its make-only dependency tllist.
  # However fcft.pc references tllist, so `pkg-config --cflags fcft ...` fails
  # completely on a fresh system without tllist. That in turn hides pixman's
  # include flags and produces the misleading `pixman.h: No such file` error.
  if ! pkg-config --exists tllist 2>/dev/null; then
    echo '==> dwlb build dependency tllist is missing; installing it'
    if command -v pacman >/dev/null 2>&1 && pacman -Si tllist >/dev/null 2>&1; then
      sudo pacman -S --needed tllist
    else
      echo 'tllist.pc is required to compile dwlb through fcft, but package tllist is unavailable.' >&2
      echo 'Enable the repository that provides tllist and rerun the installer.' >&2
      exit 1
    fi
  fi

  local pc
  for pc in wayland-client wayland-cursor fcft pixman-1 tllist; do
    if ! pkg-config --exists "$pc" 2>/dev/null; then
      echo "Required dwlb pkg-config module is still missing: $pc" >&2
      exit 1
    fi
  done

  echo "==> dwlb pkg-config dependencies ready: $(pkg-config --modversion fcft) / pixman $(pkg-config --modversion pixman-1) / tllist $(pkg-config --modversion tllist)"
}

WLR_ABI="${SANE_WLROOTS_ABI:-}"
if [ -z "$WLR_ABI" ]; then
  if pkg-config --exists wlroots-0.20 2>/dev/null; then WLR_ABI=0.20
  elif pkg-config --exists wlroots-0.19 2>/dev/null; then WLR_ABI=0.19
  else
    echo 'No supported wlroots pkg-config ABI (0.20 or 0.19) was found.' >&2
    exit 1
  fi
fi
case "$WLR_ABI" in
  0.20|0.19) ;;
  *) echo "Unsupported SANE_WLROOTS_ABI=$WLR_ABI" >&2; exit 1 ;;
esac
pkg-config --exists "wlroots-$WLR_ABI" || {
  echo "pkg-config wlroots-$WLR_ABI missing" >&2
  exit 1
}

echo "==> building against wlroots-$WLR_ABI $(pkg-config --modversion "wlroots-$WLR_ABI")"

DWL="$BUILD_ROOT/dwl"
clone_repo "$DWL" \
  https://codeberg.org/dwl/dwl.git \
  https://github.com/versality/dwl.git \
  https://github.com/djpohly/dwl.git || { echo 'Could not clone dwl.' >&2; exit 1; }

if [ "$WLR_ABI" = 0.20 ]; then
  checkout_first "$DWL" 0.9 v0.9 2c9cb2af1b || {
    echo 'Could not find a dwl 0.9 ref compatible with wlroots 0.20.' >&2
    exit 1
  }
else
  checkout_first "$DWL" v0.8 0.8 || {
    echo 'Could not find dwl v0.8/0.8 compatible with wlroots 0.19.' >&2
    exit 1
  }
fi

sed "s/@KEYBOARD_LAYOUT@/${SANE_KEYBOARD_LAYOUT:-br}/g" "$ROOT/config/dwl/config.h.in" > "$DWL/config.h"

sed -i -E "s/wlroots-0\.(19|20)/wlroots-$WLR_ABI/g" "$DWL/config.mk"
if ! grep -q "wlroots-$WLR_ABI" "$DWL/config.mk"; then
  echo "dwl config.mk does not reference wlroots-$WLR_ABI after checkout" >&2
  exit 1
fi

printf '\n# Sane rice: XWayland enabled\nXWAYLAND = -DXWAYLAND\nXLIBS = xcb xcb-icccm\n' >> "$DWL/config.mk"

DWLB="$BUILD_ROOT/dwlb"
DWLB_PIN="${SANE_DWLB_REF:-48dbe00bdb98a1ae6a0e60558ce14503616aa759}"
clone_repo "$DWLB" https://github.com/kolunmi/dwlb.git || { echo 'Could not clone dwlb.' >&2; exit 1; }
checkout_exact "$DWLB" "$DWLB_PIN" dwlb || {
  echo "Could not checkout complete dwlb source for $DWLB_PIN." >&2
  echo 'Upstream may have rewritten history; update SANE_DWLB_REF/the repository pin.' >&2
  exit 1
}
cp "$ROOT/config/dwlb/config.h" "$DWLB/config.h"

ensure_dwlb_build_deps
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
  echo "==> built and installed dwl for wlroots-$WLR_ABI + dwlb"
fi
