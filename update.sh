#!/bin/bash
set -euo pipefail
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# Re-running the installer is the update mechanism: it backs up the current
# state, refreshes packages/sources, recompiles dwl/dwlb and reapplies dotfiles.
export SANE_FULL_UPGRADE="${SANE_FULL_UPGRADE:-1}"
exec "$ROOT/install.sh"
