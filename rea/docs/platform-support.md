# REA platform / provider support matrix

Statuses below are from a live REA 6.9.0 server plus `rea doctor` and real
tool invocations, not from documentation alone.

## Android / Termux arm64 (this device)

| Capability | Status | Notes |
| --- | --- | --- |
| Core engines: Ghidra, JADX, Kuna | working | Ghidra arm64 decompiler built from source; verified with a real decompile |
| Android APK / classes / signatures | working | JADX bridge + apktool/aapt/apksigner present |
| ADB device tools (24 tools) | working after setup | `pkg install android-tools`, set `REA_ADB_PATH`. No device attached by default. |
| WASM (`inspect_wasm_artifact`) | working | WABT 1.0.42 (exact version) installed; verified |
| Firmware signature scan (`inspect_firmware_regions`, `extract_firmware`) | working with shim | Binwalk 3.1.0 + `rea-android-prlimit` shim (bionic CFI crash under `--as`) |
| Browser / CDP tools | needs a browser | No headless Chromium in Termux repos; forward a CDP port to loopback (see `scripts/setup-browser-cdp.sh`) |
| Unblob extraction | blocked | PyPI wheel is glibc-linked; source build needs a Rust `aarch64-unknown-linux-android` target that maturin/rustup do not provide |
| TShark / packet capture | not in repo | Requires TShark 4.x; needs a Linux host or a custom build |
| sigrok / signal decoding | not in repo | Requires sigrok-cli 0.7.2 |
| pwntools / EVM / Wakaru (x64-only) | unsupported host | These REA profiles are verified on Linux x64 only |
| JEB | unavailable | Commercial product; start its MCP server and set `REA_JEB_MCP_URL` |
| Mach-O / plist / codesign / asset catalog / native UI | unsupported host | Hard requirement for macOS |

`target_required` tools (open_binary, analyze_function, xrefs, etc.) are not
missing — they activate as soon as a target is opened.

## macOS (Apple Silicon / Intel)

Must be run on a real Mac (`platform/macos/setup.sh`). With Xcode CLT installed,
REA's macOS-native provider becomes available:

- `inspect_macho`, `inspect_signature`, `inspect_plist`, `inspect_asset_catalog`
- `demangle_swift`, `list_architectures`, `inspect_native_dispatch_metadata`
- `capture_native_ui_scenario`, `observe_native_ui`, `observe_native_calls`
- Browser tools via Playwright Chromium (`REA_BROWSER_EXECUTABLE`)

## iPhone / iOS

REA has **no iOS device-control provider** (only ADB for Android). iOS support
means static analysis of iOS artifacts on a macOS host:

1. Pull the app IPA from a device (`ideviceinstaller`, `iproxy`, or a local build).
2. An IPA is a ZIP: open it with REA's archive/`open_binary` inventory.
3. Inspect the embedded Mach-O executable with the macOS-native tools above
   (`inspect_macho`, `inspect_signature`, symbol/string/pseudocode analysis).
4. Use `inspect_apk_signature`-style integrity checks only for Android; iOS
   signature verification is `inspect_signature` on macOS.

Live iOS runtime instrumentation is out of REA's scope; use Frida/LLDB on a
jailbroken device or a debugger attached via Xcode for that.

## Skills

Skills are Markdown instruction sets, not compiled components. All three
installed skills (`opencode`, `report`, `reverse-engineer-anything`) load on
every platform. There is no platform-specific skill to install; platform
support is entirely a matter of MCP tools and their external providers.
