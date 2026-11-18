# REA Android/arm64 environment.
# Source this file (install.sh adds it to ~/.bashrc):
#   . "$HOME/rea-android-arm64/toolchain/rea-env.sh"

export JAVA_HOME="/data/data/com.termux/files/usr/lib/jvm/java-21-openjdk"
export GHIDRA_INSTALL_DIR="$HOME/tools/ghidra/ghidra_12.1.3_PUBLIC"
export REA_GHIDRA_STARTUP_TIMEOUT_MS=600000
export REA_JADX_MCP_JAR="$HOME/tools/jadx-mcp/jadx-headless-mcp-0.7.1-all.jar"
export REA_RIZIN_COMMAND="/data/data/com.termux/files/usr/bin/rizin"
export REA_APKTOOL_COMMAND="/data/data/com.termux/files/usr/bin/apktool"
# Optional: Kuna (if you installed the rea-mobile proot setup)
export REA_KUNA_COMMAND="$HOME/projects/rea-mobile/bin/kuna"

# Optional providers installed by scripts/install-optional-providers.sh
export REA_ADB_PATH="/data/data/com.termux/files/usr/bin/adb"
export REA_WABT_BIN_DIRECTORY="/data/data/com.termux/files/usr/bin"
export REA_BINWALK_COMMAND="/data/data/com.termux/files/usr/bin/binwalk"
# Android/bionic cannot map its CFI shadow under prlimit's --as cap; use the shim.
export REA_FIRMWARE_PRLIMIT_COMMAND="$HOME/tools/bin/rea-android-prlimit"
export REA_TSHARK_PRLIMIT_COMMAND="$HOME/tools/bin/rea-android-prlimit"
export REA_SIGROK_PRLIMIT_COMMAND="$HOME/tools/bin/rea-android-prlimit"
export REA_EVM_PRLIMIT_COMMAND="$HOME/tools/bin/rea-android-prlimit"
export REA_JAVASCRIPT_PRLIMIT_COMMAND="$HOME/tools/bin/rea-android-prlimit"

# arm64-capable providers enabled by patch-rea-arm64-gates.cjs:
export REA_PWNTOOLS_PYTHON="$HOME/tools/pwntools-venv/bin/python"
export REA_WAKARU_COMMAND="$HOME/tools/bin/rea-wakaru"
# Providers running inside the Ubuntu proot (glibc-backed).
export REA_TSHARK_COMMAND="$HOME/tools/bin/rea-tshark"
export REA_SIGROK_COMMAND="$HOME/tools/bin/rea-sigrok"
# Browser: set REA_BROWSER_EXECUTABLE once a Chromium binary is available.
# REA's browser tools can also connect to any loopback CDP endpoint (port 9222).