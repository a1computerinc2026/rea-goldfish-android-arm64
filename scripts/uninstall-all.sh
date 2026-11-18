#!/data/data/com.termux/files/usr/bin/env bash
# Uninstall EGM (Goldfish) and REA from the merged repository root.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "== Uninstalling EGM (Goldfish) =="
bash "$ROOT/egm/scripts/uninstall.sh"
echo
echo "== Uninstalling REA =="
bash "$ROOT/rea/scripts/uninstall.sh"
echo
echo "Done. Restart OpenCode."
