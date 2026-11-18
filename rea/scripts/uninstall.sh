#!/data/data/com.termux/files/usr/bin/bash
# Uninstall: revert the REA patch, remove the shell hook, and delete downloaded engines.
# Termux packages and the OpenCode registration are left alone unless you remove them
# yourself (see README -> Uninstall).
set -uo pipefail
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"

echo "[*] Restoring REA launcher backup"
REA_MJS="$("$HOME_DIR/../usr/bin/node" -e '
  const fs=require("fs"), path=require("path");
  const nm=path.join(process.env.PREFIX||"/data/data/com.termux/files/usr","lib/node_modules/rea-agents/scripts/rea.mjs");
  process.stdout.write(fs.existsSync(nm)?nm:"");
' 2>/dev/null || true)"
if [ -n "$REA_MJS" ] && [ -f "$REA_MJS.orig-android-backup" ]; then
  cp -p "$REA_MJS.orig-android-backup" "$REA_MJS" && echo "    restored $REA_MJS"
fi

echo "[*] Removing shell hook"
if [ -f "$HOME_DIR/.bashrc" ]; then
  grep -v 'source "$HOME/.rea-env.sh"' "$HOME_DIR/.bashrc" > "$HOME_DIR/.bashrc.tmp" \
    && mv "$HOME_DIR/.bashrc.tmp" "$HOME_DIR/.bashrc" && echo "    cleaned ~/.bashrc"
fi

echo "[*] Removing downloaded engines (tools/)"
rm -rf "$HOME_DIR/tools/ghidra" "$HOME_DIR/tools/jadx-mcp" \
       "$HOME_DIR/tools/src/ghidra-src-"* "$HOME_DIR/tools/rea-android-shim.cjs" \
       "$HOME_DIR/tools/android-build" 2>/dev/null || true
echo "    done"
echo
echo "Still installed via pkg (remove manually if wanted):"
echo "  pkg uninstall jadx apktool dex2jar rizin radare2 binutils aapt aapt2 apksigner"
echo "  npm uninstall -g rea-agents"