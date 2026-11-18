#!/data/data/com.termux/files/usr/bin/bash
# Run the REA doctor checks for this Android/arm64 setup and print a summary.
# Usage: bash scripts/verify.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
. "$ROOT/toolchain/rea-env.sh" 2>/dev/null || . "$HOME/.rea-env.sh"

echo "== rea =="; rea --version 2>&1 | head -1
echo "== doctor =="; rea doctor --client opencode --provider ghidra --provider jadx --provider kuna --format json 2>&1 \
  | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  let j; try{j=JSON.parse(s);}catch(e){console.log("  (doctor output was not JSON)");process.exit(0);}
  console.log("  healthy:", j.healthy);
  for (const c of (j.scope_checks||[])) console.log("  "+(c.ok?"OK  ":"FAIL")+" "+c.name+(c.detail?": "+c.detail:""));
});'
echo "== engines =="
for c in jadx apktool aapt aapt2 apksigner rizin radare2 readelf objdump nm strings keytool; do
  printf "  %-11s " "$c"; command -v "$c" >/dev/null 2>&1 && echo present || echo MISSING
done
echo "  ghidra      ${GHIDRA_INSTALL_DIR:-<unset>}"
echo "  jadx-mcp    ${REA_JADX_MCP_JAR:-<unset>}"