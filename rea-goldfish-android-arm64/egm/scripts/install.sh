#!/data/data/com.termux/files/usr/bin/env bash
# Install official EGM into OpenCode v2 on Termux / Android arm64.
# Usage: bash scripts/install.sh [--force]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/toolchain/egm-env.sh"

command -v python3 >/dev/null 2>&1 || { echo "python3 is required (pkg install python)"; exit 2; }

echo "== EGM Android installer =="
echo "  arch      : $(uname -m)"
echo "  python    : $(python3 --version 2>&1)"
echo "  opencode  : $(opencode --version 2>&1 | head -1)"
echo "  bundle    : $EGM_BUNDLE_DIR"
echo "  config    : $OPENCODE_CONFIG_DIR"
echo
python3 "$ROOT/toolchain/install_egm.py" install "$@"
echo
echo "Restart OpenCode so it loads the new skills and agents."
