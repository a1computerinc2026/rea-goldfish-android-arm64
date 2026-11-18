#!/data/data/com.termux/files/usr/bin/env bash
# Install REA + EGM (Goldfish) from the merged repository root.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "== Installing REA =="
bash "$ROOT/rea/scripts/install.sh"
echo
echo "== Installing EGM (Goldfish) =="
bash "$ROOT/egm/scripts/install.sh"
echo
echo "Both installed. Fully restart OpenCode to load the MCP server and EGM agents."
