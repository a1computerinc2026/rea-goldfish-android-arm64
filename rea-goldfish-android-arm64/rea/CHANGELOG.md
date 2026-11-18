# Changelog

## v1.0.0 — 2026-11-18
- First public release of the REA Android/arm64 (Termux) setup.
- Installs and verifies Ghidra 12.1.3 (native arm64 decompiler built on-device),
  JADX 1.5.6 + jadx-headless-mcp 0.7.1 bridge, Kuna 1.990 (optional proot),
  apktool, dex2jar, aapt/aapt2, apksigner, binutils, rizin, radare2.
- Applies the Android→Linux platform shim to REA so its Ghidra/JADX/Kuna
  providers pass `rea doctor`.
- Registers REA's MCP server in OpenCode with the correct environment.
- Verified: REA Ghidra decompilation, JADX APK inspection, APK signature
  inspection, and a full APK build→sign→analyze pipeline on Android arm64.