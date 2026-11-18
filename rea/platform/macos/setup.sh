#!/usr/bin/env bash
# REA on macOS (Apple Silicon or Intel) + browser + iOS companion tooling.
# MUST be run on a Mac. This script cannot be executed from Android/Termux.
set -uo pipefail

echo "== REA macOS setup =="
if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: this script requires macOS (uname -s = Darwin)." >&2
  echo "The Android build cannot install macOS-only REA tools. Run this on a Mac." >&2
  exit 1
fi

# 1. Xcode Command Line Tools provide otool, codesign, plutil, nm, swift-demangle,
#    assetutil and the other utilities behind REA's native-macOS provider.
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Xcode Command Line Tools (approve the dialog if it appears)..."
  xcode-select --install || true
else
  echo "[skip] Xcode CLT: $(xcode-select -p)"
fi

# 2. Homebrew for REA dependencies and iOS device tooling.
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install it from https://brew.sh first, then re-run." >&2
else
  brew install node@26 java@21
  brew install --cask temurin@21 2>/dev/null || true

  # iOS device inspection companion (REA itself has no iOS device provider;
  # these tools let you pull IPA files and logs for REA to analyse statically).
  brew install libimobiledevice ideviceinstaller iproxy usbmuxd || true
fi

# 3. REA itself (engines are configured by REA/rea doctor on macOS).
if ! command -v rea >/dev/null 2>&1; then
  npm i -g rea-agents@6.9.0
else
  echo "[skip] rea: $(rea --version 2>&1 | head -1)"
fi

# 4. Browser support: Playwright's Chromium gives REA a local CDP-capable browser.
npm i -g playwright@latest 2>/dev/null || true
npx -y playwright install chromium 2>/dev/null || true
CHROME="$(find "$HOME/Library/Caches/ms-playwright" -type f -name 'Chrome' -o -name 'headless_shell' 2>/dev/null | head -1)"
if [ -n "$CHROME" ]; then
  echo "export REA_BROWSER_EXECUTABLE=\"$CHROME\"" > "$HOME/.rea-browser-env.sh"
fi

# 5. Environment template.
cat > "$HOME/.rea-env.sh" <<'EOF'
# REA macOS environment
export JAVA_HOME="$(/usr/libexec/java_home -v 21 2>/dev/null || true)"
export REA_BROWSER_EXECUTABLE="${REA_BROWSER_EXECUTABLE:-}"
# Optional commercial/specialised providers:
# export REA_TSHARK_COMMAND="/Applications/Wireshark.app/Contents/MacOS/tshark"  # macOS: often unsupported host
# export REA_JEB_MCP_URL="http://127.0.0.1:8425/mcp"
EOF

echo
echo "== verify =="
echo "  rea doctor --client opencode"
echo "  npx -y playwright install chromium   # if browser tools report no executable"
echo
echo "Note: REA's macOS-only tools (inspect_macho, inspect_signature,"
echo "inspect_asset_catalog, inspect_plist, demangle_swift, native UI) work only"
echo "on a real macOS host. iOS apps are analysed as IPA (ZIP) + Mach-O artifacts."
