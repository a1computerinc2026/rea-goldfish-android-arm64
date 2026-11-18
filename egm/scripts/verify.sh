#!/data/data/com.termux/files/usr/bin/env bash
# Health check for EGM on Android/arm64.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/toolchain/egm-env.sh"
python3 "$ROOT/toolchain/verify_egm.py"
