# Build script for the Ghidra arm64 native decompiler (no Docker needed).
#
# Ghidra's release zip only ships decompiler natives for x86-64. This builds the
# arm64 decompiler from the matching source tag using the host's C++ toolchain
# (Termux clang/g++/make/bison/flex). Run once; output is copied into the
# extracted Ghidra by install.sh.
#
# Usage: bash build-decompiler.sh [GHIDRA_VERSION] [OUT_FILE]
#   GHIDRA_VERSION defaults to 12.1.3
#   OUT_FILE defaults to ./ghidra_opt
set -euo pipefail

GHIDRA_VER="${1:-12.1.3}"
TAG="Ghidra_${GHIDRA_VER}_build"
OUT="${2:-ghidra_opt}"
SRC="${TMPDIR:-/tmp}/ghidra-src-${GHIDRA_VER}"

echo "[*] Fetching decompiler source at tag ${TAG}"
if [ ! -d "$SRC/.git" ]; then
  rm -rf "$SRC"
  mkdir -p "$SRC"
  git init -q "$SRC"
  git -C "$SRC" remote add origin https://github.com/NationalSecurityAgency/ghidra.git
  git -C "$SRC" config core.sparseCheckout true
  printf 'Ghidra/Features/Decompiler/src/decompile/\n' > "$SRC/.git/info/sparse-checkout"
fi
git -C "$SRC" fetch -q --depth 1 origin "$TAG"
git -C "$SRC" checkout -q FETCH_HEAD

echo "[*] Building arm64 decompiler (ARCH_TYPE= overrides the x86 Makefile default)"
cd "$SRC/Ghidra/Features/Decompiler/src/decompile/cpp"
make ARCH_TYPE= -j"$(nproc)" ghidra_opt

cp ghidra_opt "$OUT"
echo "[*] Built: $OUT"
file "$OUT" 2>/dev/null || true
echo "[*] Install it with:"
echo "    mkdir -p \"\$GHIDRA_INSTALL_DIR/Ghidra/Features/Decompiler/os/linux_arm_64\""
echo "    cp \"$OUT\" \"\$GHIDRA_INSTALL_DIR/Ghidra/Features/Decompiler/os/linux_arm_64/decompile\""
echo "    chmod +x \"\$GHIDRA_INSTALL_DIR/Ghidra/Features/Decompiler/os/linux_arm_64/decompile\""