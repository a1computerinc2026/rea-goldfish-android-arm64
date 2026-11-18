#!/data/data/com.termux/files/usr/bin/bash
# Idempotent installer for REA on Termux / Android arm64.
# Usage: bash scripts/install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
NODE_BIN="$(command -v node)"
REA_BIN="$(command -v rea || true)"
GHIDRA_VER="${GHIDRA_VER:-12.1.3}"
GHIDRA_TAG="Ghidra_${GHIDRA_VER}_build"
GHIDRA_DIR="$HOME_DIR/tools/ghidra/ghidra_${GHIDRA_VER}_PUBLIC"
JADX_MCP_DIR="$HOME_DIR/tools/jadx-mcp"
JADX_MCP_JAR="$JADX_MCP_DIR/jadx-headless-mcp-0.7.1-all.jar"
JADX_MCP_SHA="6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75"

echo "[1/9] Installing Termux packages"
pkg install -y \
  openjdk-21 jadx apktool dex2jar rizin radare2 binutils \
  aapt aapt2 apksigner gh git curl wget unzip tar >/dev/null

echo "[2/9] Installing REA (Node.js package)"
if ! command -v rea >/dev/null 2>&1; then
  npm install -g rea-agents@6.9.0
fi
echo "      rea $("$REA_BIN" --version 2>/dev/null || echo '?')"

echo "[3/9] Downloading Ghidra ${GHIDRA_VER} (x86-64 release)"
mkdir -p "$HOME_DIR/tools/ghidra"
if [ ! -d "$GHIDRA_DIR" ]; then
  URL="$(node -e '
    const v=process.argv[1], tag="Ghidra_"+v+"_build";
    fetch("https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/tags/"+tag,
      {headers:{"User-Agent":"rea-android-arm64"}})
      .then(r=>r.json())
      .then(j=>{const a=(j.assets||[]).find(x=>/^ghidra_.*_PUBLIC\\.zip$/.test(x.name)); process.stdout.write(a?a.browser_download_url:"");})
      .catch(()=>process.stdout.write(""));
  ' "$GHIDRA_VER")"
  [ -n "$URL" ] || URL="https://github.com/NationalSecurityAgency/ghidra/releases/download/${GHIDRA_TAG}/ghidra_${GHIDRA_VER}_PUBLIC_20260817.zip"
  echo "      $URL"
  curl -fL --retry 3 -C - -o "$HOME_DIR/tools/ghidra/ghidra.zip" "$URL"
  ( cd "$HOME_DIR/tools/ghidra" && unzip -q -o ghidra.zip )
else
  echo "      Ghidra already present at $GHIDRA_DIR"
fi

echo "[4/9] Building the arm64 native decompiler (native toolchain, no Docker)"
DECOMP="$GHIDRA_DIR/Ghidra/Features/Decompiler/os/linux_arm_64/decompile"
if [ ! -x "$DECOMP" ]; then
  mkdir -p "$HOME_DIR/tools/src"
  SRC="$HOME_DIR/tools/src/ghidra-src-${GHIDRA_VER}"
  if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$SRC"
    git init -q "$SRC"
    git -C "$SRC" remote add origin https://github.com/NationalSecurityAgency/ghidra.git
    git -C "$SRC" config core.sparseCheckout true
    printf 'Ghidra/Features/Decompiler/src/decompile/\n' > "$SRC/.git/info/sparse-checkout"
  fi
  git -C "$SRC" fetch -q --depth 1 origin "$GHIDRA_TAG"
  git -C "$SRC" checkout -q FETCH_HEAD
  ( cd "$SRC/Ghidra/Features/Decompiler/src/decompile/cpp" \
      && make ARCH_TYPE= -j"$(nproc)" ghidra_opt >"$HOME_DIR/tools/src/ghidra-decompile-build.log" 2>&1 )
  mkdir -p "$(dirname "$DECOMP")"
  cp "$SRC/Ghidra/Features/Decompiler/src/decompile/cpp/ghidra_opt" "$DECOMP"
  chmod +x "$DECOMP"
else
  echo "      arm64 decompiler already present"
fi

echo "[5/9] Installing the JADX MCP bridge (pinned 0.7.1, SHA-256 verified)"
mkdir -p "$JADX_MCP_DIR"
if [ ! -f "$JADX_MCP_JAR" ]; then
  curl -fL --retry 3 -o "$JADX_MCP_JAR" \
    "https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar"
fi
printf '%s  %s\n' "$JADX_MCP_SHA" "$JADX_MCP_JAR" | sha256sum -c - \
  || { echo "ERROR: JADX MCP JAR SHA-256 mismatch"; exit 1; }

echo "[6/9] Fetching android-34.jar framework (needed by aapt/aapt2 for APK builds)"
mkdir -p "$HOME_DIR/tools/android-build"
if [ ! -s "$HOME_DIR/tools/android-build/android-34.jar" ]; then
  curl -fsSL --retry 3 -o "$HOME_DIR/tools/android-build/android-34.jar" \
    "https://raw.githubusercontent.com/Sable/android-platforms/master/android-34/android.jar" \
    || echo "      WARNING: android-34.jar download failed (aapt link will need -I)"
fi

echo "[7/9] Applying the Android -> Linux platform shim to REA"
# Resolve the real launcher path robustly.
REA_MJS="$(node -e '
  const fs=require("fs"), path=require("path");
  const which=process.argv[1];
  let p=fs.realpathSync(which);
  if (p.endsWith("scripts/rea.mjs")) { process.stdout.write(p); process.exit(0); }
  // Try the package root of the global rea-agents install.
  const nm=path.join(process.env.PREFIX||"/data/data/com.termux/files/usr","lib/node_modules/rea-agents/scripts/rea.mjs");
  process.stdout.write(fs.existsSync(nm)?nm:p);
' "$(command -v rea)")"
if [ -f "$REA_MJS" ] && ! grep -q 'Android/arm64 compatibility shim' "$REA_MJS"; then
  cp -p "$REA_MJS" "$REA_MJS.orig-android-backup"
  python3 - "$REA_MJS" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
shim = '''#!/usr/bin/env node

// --- Android/arm64 compatibility shim (installed by rea-android-arm64) ---
if (process.platform === "android") {
  Object.defineProperty(process, "platform", {
    value: "linux",
    configurable: true,
    enumerable: true,
    writable: false,
  });
}
// --- end shim ---
'''
assert s.startswith('#!/usr/bin/env node\n')
open(p, 'w', encoding='utf-8').write(shim + s[len('#!/usr/bin/env node\n'):])
PY
  echo "      patched $REA_MJS (backup: $REA_MJS.orig-android-backup)"
else
  echo "      shim already present"
fi
cp "$ROOT/toolchain/rea-android-shim.cjs" "$HOME_DIR/tools/rea-android-shim.cjs"

echo "[8/9] Writing environment and shell hook"
cp "$ROOT/toolchain/rea-env.sh" "$HOME_DIR/.rea-env.sh"
if [ -f "$HOME_DIR/.bashrc" ]; then
  grep -q 'source "$HOME/.rea-env.sh"' "$HOME_DIR/.bashrc" \
    || printf '\n# REA Android/arm64 environment\n. "$HOME/.rea-env.sh"\n' >> "$HOME_DIR/.bashrc"
else
  printf '# REA Android/arm64 environment\n. "$HOME/.rea-env.sh"\n' > "$HOME_DIR/.bashrc"
fi
chmod +x "$ROOT"/toolchain/wrappers/*

echo "[9/9] Registering REA in OpenCode"
. "$HOME_DIR/.rea-env.sh"
if command -v rea >/dev/null 2>&1; then
  rea setup --client opencode --skill=false --yes >/dev/null 2>&1 \
    && echo "      OpenCode registration updated" \
    || echo "      WARNING: rea setup failed (run it manually later)"
else
  echo "      WARNING: rea not on PATH; run 'rea setup --client opencode --skill=false --yes' later"
fi

echo
echo "Done. Verify with:"
echo "  . ~/.rea-env.sh && rea doctor --client opencode --provider ghidra --provider jadx --provider kuna"
echo "Then restart OpenCode."