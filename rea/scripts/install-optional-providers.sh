#!/data/data/com.termux/files/usr/bin/bash
# Install the REA providers that are missing by default on Termux/arm64.
# Idempotent. Safe to re-run. Installs into Termux only.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="/data/data/com.termux/files/usr"
HOME_DIR="/data/data/com.termux/files/home"

echo "== REA optional providers (Termux/arm64) =="

# Some third-party apt repos in the wild return 404 for their Packages index,
# which makes `pkg install` abort even when the official repo is healthy.
# Use a clean, temporary sources list so the official Termux repo still works.
CLEAN_SOURCES="$PREFIX/tmp/opencode/termux-clean.list"
mkdir -p "$(dirname "$CLEAN_SOURCES")"
printf 'deb https://mirrors.cbrx.io/apt/termux/termux-main stable main\n' > "$CLEAN_SOURCES"
APT=(apt-get -o "Dir::Etc::sourcelist=$CLEAN_SOURCES" -o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0 install -y)

install_pkg() {
  local pkg="$1" label="$2"
  if command -v "$label" >/dev/null 2>&1; then
    echo "  [skip] $pkg (already installed)"
  else
    echo "  [install] $pkg"
    "${APT[@]}" "$pkg" || echo "  [warn] $pkg could not be installed"
  fi
}

install_pkg android-tools adb
install_pkg wabt wasm2wat
install_pkg binwalk binwalk
install_pkg util-linux prlimit
install_pkg procps ps

# bionic's CFI shadow mapping crashes under prlimit's --as cap. Install the
# Android shim that drops incompatible resource flags into a noexec-safe dir.
SHIM="$HOME_DIR/tools/bin/rea-android-prlimit"
mkdir -p "$(dirname "$SHIM")"
cp "$ROOT/toolchain/rea-android-prlimit.sh" "$SHIM"
chmod +x "$SHIM"
echo "  [ok] prlimit shim -> $SHIM"

echo
echo "== verification =="
for c in adb wasm2wat binwalk prlimit ps; do
  printf '  %-10s ' "$c"; command -v "$c" >/dev/null 2>&1 && echo present || echo MISSING
done
echo "  wabt:    $(wasm2wat --version 2>&1 | head -1)"
echo "  binwalk: $(binwalk --version 2>&1 | head -1)"
echo
echo "Providers now enabled via the environment (restart OpenCode to load the MCP env):"
echo "  REA_ADB_PATH, REA_WABT_BIN_DIRECTORY, REA_BINWALK_COMMAND, REA_*_PRLIMIT_COMMAND"
echo
echo "Not installable on Android (need a Linux/macOS host or commercial licence):"
echo "  TShark/Wireshark, sigrok-cli, Unblob, pwntools x64, Wakaru x64, EVM x64,"
echo "  JEB, and all macOS/iOS Mach-O tools. See docs/platform-support.md."
