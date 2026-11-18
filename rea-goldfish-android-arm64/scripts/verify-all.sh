#!/data/data/com.termux/files/usr/bin/env bash
# Verify REA + EGM (Goldfish) from the merged repository root.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rc=0
echo "== REA =="
bash "$ROOT/rea/scripts/verify.sh" || rc=1
echo
echo "== EGM (Goldfish) =="
bash "$ROOT/egm/scripts/verify.sh" || rc=1
echo
if [ "$rc" -eq 0 ]; then echo "ALL HEALTHY"; else echo "SOME CHECKS FAILED"; fi
exit "$rc"
