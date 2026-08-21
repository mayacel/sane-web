#!/bin/bash
set -euo pipefail

MODE="${1:-manual}"
case "$MODE" in
  preflight|post-upgrade|post-install|manual) ;;
  *) printf 'usage: %s {preflight|post-upgrade|post-install|manual}\n' "$0" >&2; exit 2 ;;
esac

say() { printf '[sane-system-check] %s\n' "$*"; }
warn() { printf '[sane-system-check] WARNING: %s\n' "$*" >&2; }
die() { printf '[sane-system-check] ERROR: %s\n' "$*" >&2; exit 1; }

[ -r /etc/os-release ] || die "/etc/os-release is missing"
# shellcheck disable=SC1091
. /etc/os-release

check_fstab_mounts() {
  local expected actual target
  command -v findmnt >/dev/null 2>&1 || return 0
  expected="$(findmnt --fstab -rn -o TARGET 2>/dev/null || true)"
  for target in /boot /efi /boot/efi; do
    if printf '%s\n' "$expected" | grep -Fxq "$target"; then
      actual="$(findmnt -rn -T "$target" -o TARGET 2>/dev/null | head -n1 || true)"
      [ "$actual" = "$target" ] || die "$target is configured in /etc/fstab but is not mounted on its own filesystem (actual mount: ${actual:-none}). Refusing package/kernel changes."
    fi
  done
}

check_systemd() {
  [ "${ID:-}" = arch ] || return 0
  local expected_runtime

  [ "$(cat /proc/1/comm 2>/dev/null || true)" = systemd ] ||
    die "Arch detected but PID 1 is not systemd"

  command -v systemctl >/dev/null 2>&1 || die "systemctl is missing"
  systemctl show-environment >/dev/null 2>&1 ||
    die "systemd PID 1 exists but its control channel is not responding"

  [ -S /run/systemd/private ] ||
    die "/run/systemd/private is missing or is not a socket"

  if command -v busctl >/dev/null 2>&1; then
    busctl --system --no-pager list >/dev/null 2>&1 ||
      die "the system D-Bus is not reachable"
  fi

  systemctl is-active --quiet systemd-logind.service 2>/dev/null ||
    die "systemd-logind is not active; refusing to mask a broken login/runtime session"

  expected_runtime="/run/user/$(id -u)"
  [ -n "${XDG_RUNTIME_DIR:-}" ] ||
    die "XDG_RUNTIME_DIR is unset; logind/PAM user-session setup is not healthy"
  [ "$XDG_RUNTIME_DIR" = "$expected_runtime" ] ||
    die "XDG_RUNTIME_DIR is $XDG_RUNTIME_DIR, expected the pam_systemd runtime $expected_runtime"
  [ -d "$XDG_RUNTIME_DIR" ] ||
    die "XDG_RUNTIME_DIR points to a missing directory: $XDG_RUNTIME_DIR"
  [ -O "$XDG_RUNTIME_DIR" ] ||
    die "XDG_RUNTIME_DIR is not owned by the current user: $XDG_RUNTIME_DIR"

  if command -v NetworkManager >/dev/null 2>&1 &&
     systemctl is-active --quiet NetworkManager.service 2>/dev/null; then
    if ! systemctl is-enabled --quiet NetworkManager.service 2>/dev/null; then
      warn "NetworkManager is active but not enabled for boot"
    fi
  fi
}

check_network() {
  command -v ip >/dev/null 2>&1 || die "iproute2/ip command is missing"

  local route4 route6
  route4="$(ip -4 route show default 2>/dev/null | head -n1 || true)"
  route6="$(ip -6 route show default 2>/dev/null | head -n1 || true)"
  if [ -z "$route4" ] && [ -z "$route6" ]; then
    if command -v lspci >/dev/null 2>&1 &&
       lspci 2>/dev/null | grep -qi 'VirtualBox'; then
      die "no default route. In VirtualBox this usually means the guest has link but no DHCP/network service."
    fi
    die "no IPv4 or IPv6 default route is configured"
  fi

  command -v getent >/dev/null 2>&1 || die "getent is missing"
  getent ahosts archlinux.org >/dev/null 2>&1 ||
    die "DNS resolution failed for archlinux.org"

  say "network route + DNS: OK"
}

check_running_kernel() {
  local running
  running="$(uname -r)"
  [ -d "/usr/lib/modules/$running" ] ||
    die "running kernel $running has no matching /usr/lib/modules/$running"
  say "running kernel modules: $running"
}

kernel_file_version() {
  local image="$1"
  command -v file >/dev/null 2>&1 || return 0
  file -b "$image" 2>/dev/null |
    sed -n 's/.*version \([^ ]*\).*/\1/p' |
    head -n1
}

check_mkinitcpio_outputs() {
  local pkg="$1" preset outputs path checked
  preset="/etc/mkinitcpio.d/$pkg.preset"
  [ -f "$preset" ] || {
    warn "$preset does not exist; skipping mkinitcpio output verification for $pkg"
    return 0
  }

  outputs="$(
    bash -c '
      set +u
      source "$1"
      declare -p PRESETS >/dev/null 2>&1 || exit 0
      for p in "${PRESETS[@]}"; do
        eval "img=\${${p}_image:-}"
        eval "uki=\${${p}_uki:-}"
        [ -n "$img" ] && printf "%s\\n" "$img"
        [ -n "$uki" ] && printf "%s\\n" "$uki"
      done
    ' _ "$preset" 2>/dev/null || true
  )"

  checked=0
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
      /*)
        checked=1
        [ -f "$path" ] ||
          die "$preset declares boot artifact $path, but that file is missing after the kernel transaction"
        ;;
      *)
        warn "$preset declares relative boot artifact $path; existence cannot be verified reliably"
        ;;
    esac
  done <<< "$outputs"

  if [ "$checked" -eq 1 ]; then
    say "$pkg mkinitcpio outputs: present"
  else
    warn "$preset exposed no absolute image/UKI output path to verify"
  fi
}

check_kernel_payloads() {
  local pkg modulever package_image package_ver boot_image boot_ver found
  found=0

  for pkg in linux linux-lts linux-zen linux-hardened; do
    pacman -Q "$pkg" >/dev/null 2>&1 || continue
    found=1

    modulever="$(
      pacman -Ql "$pkg" 2>/dev/null |
        sed -n 's#^[^ ]* /usr/lib/modules/\([^/]*\)/$#\1#p' |
        head -n1
    )"
    [ -n "$modulever" ] ||
      die "could not determine the installed module directory for $pkg"
    [ -d "/usr/lib/modules/$modulever" ] ||
      die "$pkg owns kernel $modulever but /usr/lib/modules/$modulever is missing"

    # Current Arch kernel packages keep their canonical kernel image in the
    # module tree. /boot copies and UKIs are produced by mkinitcpio/kernel hooks
    # and are not necessarily files owned directly by the kernel package.
    package_image="/usr/lib/modules/$modulever/vmlinuz"
    [ -f "$package_image" ] ||
      die "$pkg is installed but its canonical kernel image $package_image is missing"

    package_ver="$(kernel_file_version "$package_image")"
    if [ -n "$package_ver" ] && [ "$package_ver" != "$modulever" ]; then
      die "$package_image contains kernel $package_ver but its module directory is $modulever"
    fi

    # Traditional mkinitcpio layouts still expose /boot/vmlinuz-<pkg>. If it is
    # present, compare it with the newly installed module tree. UKI-only layouts
    # legitimately omit this path, so absence alone is not an error.
    boot_image="/boot/vmlinuz-$pkg"
    if [ -f "$boot_image" ]; then
      boot_ver="$(kernel_file_version "$boot_image")"
      if [ -n "$boot_ver" ] && [ "$boot_ver" != "$modulever" ]; then
        die "$boot_image contains kernel $boot_ver but installed modules are $modulever. /boot may not be the filesystem used at boot."
      fi
      say "$pkg traditional boot kernel: $modulever"
    fi

    check_mkinitcpio_outputs "$pkg"
    say "$pkg installed kernel payload: $modulever"
  done

  [ "$found" -eq 1 ] || warn "no standard Arch kernel package was detected; skipped kernel payload comparison"
}

check_systemd_boot() {
  command -v bootctl >/dev/null 2>&1 || return 0
  bootctl is-installed >/dev/null 2>&1 || return 0

  local esp actual
  esp="$(bootctl --print-esp-path 2>/dev/null || true)"
  [ -n "$esp" ] ||
    die "systemd-boot is installed but the ESP cannot be located/mounted"
  actual="$(findmnt -rn -T "$esp" -o TARGET 2>/dev/null | head -n1 || true)"
  [ -n "$actual" ] ||
    die "systemd-boot ESP path $esp is not on a mounted filesystem"
  [ "$actual" != "/" ] ||
    die "systemd-boot reports ESP path $esp, but it resolves to the root filesystem; the ESP is probably not mounted"

  say "systemd-boot ESP: $esp (mount $actual)"
}

check_pacman_state() {
  command -v pacman >/dev/null 2>&1 || die "pacman is missing"
  [ ! -e /var/lib/pacman/db.lck ] ||
    die "/var/lib/pacman/db.lck exists; another/interrupted pacman transaction must be resolved first"

  pacman -Q systemd >/dev/null 2>&1 || {
    [ "${ID:-}" = arch ] && die "the systemd package is not registered as installed"
    true
  }
  pacman -Q dbus >/dev/null 2>&1 || die "the dbus package is not registered as installed"
}

say "mode: $MODE"
check_pacman_state
check_fstab_mounts
check_systemd
check_network

case "$MODE" in
  preflight)
    check_running_kernel
    check_systemd_boot
    ;;
  manual)
    if [ -d "/usr/lib/modules/$(uname -r)" ]; then
      check_running_kernel
    else
      warn "running kernel $(uname -r) has no matching module directory; this can be normal immediately after a kernel upgrade, but requires a reboot if the installed boot payload is healthy"
    fi
    check_kernel_payloads
    check_systemd_boot
    ;;
  post-upgrade|post-install)
    check_kernel_payloads
    check_systemd_boot
    ;;
esac

say "$MODE checks passed"
