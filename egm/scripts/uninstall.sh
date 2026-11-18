#!/data/data/com.termux/files/usr/bin/env bash
# Undo the EGM Android installation (restores prior opencode.json / legacy plugin).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/toolchain/egm-env.sh"
python3 "$ROOT/toolchain/install_egm.py" uninstall "$@"
echo "Uninstalled. Restart OpenCode."
