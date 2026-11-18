> [!IMPORTANT]
> This is the **Android/arm64 (Termux) setup for REA**, not REA itself.
> Get REA at https://github.com/morluto/rea — this repo only installs and
> customizes it so its engines run on Android.

# REA on Android (Termux, arm64)

> **This is the `rea/` component of the merged [`rea-goldfish-android-arm64`](../README.md) project.** From the merged repository root, run `bash rea/scripts/install.sh` and `bash rea/scripts/verify.sh`. The standalone install steps below still work from inside `rea/`.

**Turn your Android phone into a reverse-engineering workstation.** This project installs
[REA](https://github.com/morluto/rea) and its analysis engines — **Ghidra, JADX, Kuna** —
on **Termux / Android arm64**, where they normally refuse to run.

Everything here is open source (MIT). It contains **only installation glue and docs** —
no proprietary tools, no cracked software. Ghidra, Kuna, JADX, REA, etc. keep their own
licenses and are downloaded from their official sources.

<!-- ADD A SCREENSHOT HERE: put a PNG in docs/ and link it, e.g.
![screenshot](docs/screenshot.png) -->

---

## What you get

| Engine | License | What it does |
| --- | --- | --- |
| **Ghidra** 12.1.3 | Apache-2.0 | Decompile native code (`.so`, ELF, etc.) to C-like pseudocode |
| **JADX** 1.5.6 + bridge | Apache-2.0 | Decompile Android APKs to readable Java |
| **Kuna** 1.990 | Apache-2.0 | Fast native decompiler (optional, via proot) |
| **apktool, dex2jar, aapt, apksigner** | GPL/Apache | Build, decode and sign APKs |
| **rizin, radare2, binutils** | GPL | Disassembly, ELF inspection |

**Not included (and why):** Hopper and IDA Pro are **proprietary commercial products**.
They can't legally be installed or redistributed here. Kuna and Ghidra are the free,
open-source alternatives.

---

## Requirements

- **Android device with Termux** (arm64 / aarch64). No root needed.
- About **1.5 GB** free space (Ghidra is ~550 MB, plus build tools).
- A GitHub account if you want to publish this project (not needed to use it).

---

## Install (beginner, step by step)

1. **Install Termux** from [F-Droid](https://f-droid.org/packages/com.termux/) or GitHub
   (the Play Store version is outdated).
2. Open Termux and run:

   ```bash
   pkg update -y
   pkg install -y git
   git clone https://github.com/YOUR-USERNAME/rea-goldfish-android-arm64.git
   cd rea-goldfish-android-arm64/rea   # or use: bash rea/scripts/install.sh from repo root
   bash scripts/install.sh
   ```

   The installer is **idempotent** — running it again is safe. It:

   - installs Termux packages (Java 21, Ghidra's dependencies, JADX, apktool, rizin, …)
   - installs REA (`npm i -g rea-agents@6.9.0`)
   - downloads Ghidra and **builds the arm64 decompiler** from source (no Docker needed)
   - downloads the pinned JADX bridge and verifies its SHA-256
   - applies the **Android→Linux platform shim** so REA's engines pass its checks
   - writes the environment and registers REA in **OpenCode**

3. **Check it worked:**

   ```bash
   bash scripts/verify.sh
   ```

   You want `healthy: true` and `OK` on `ghidra`, `jadx`, `kuna`.

4. **Restart OpenCode** (close and reopen the app) so it loads the new MCP server.

---

## Use it

```bash
# make sure the environment is loaded (already added to ~/.bashrc)
. ~/.rea-env.sh

# decompile a native library with Ghidra
rea analyze path/to/lib.so --provider ghidra --format json

# decompile one function
rea decompile path/to/lib.so --procedure main --provider ghidra --format json

# inspect an APK (package, manifest, classes, signatures)
rea inspect-android-package path/to/app.apk --format json
rea inspect-android-class  path/to/app.apk com.example.Foo --format json
rea inspect-apk-signature  path/to/app.apk --format json

# or use the engines directly
jadx path/to/app.apk -d out        # APK -> Java source
apktool d path/to/app.apk -o out   # APK -> resources + manifest
d2j-dex2jar path/to/app.apk        # APK -> JAR
rizin -A path/to/lib.so            # disassembly
```

Inside **OpenCode**, after the restart, REA exposes **255 tools** (`open_binary`,
`inspect_android_package`, `decompile`, …). Just ask the agent to analyze a file.

---

## Optional providers, browser & other platforms

Beyond the three core engines, extra REA providers can be enabled:

```bash
bash scripts/install-optional-providers.sh   # ADB, WABT, binwalk, bionic prlimit shim
bash scripts/setup-browser-cdp.sh            # browser/CDP configuration helper
```

`inspect_wasm_artifact`, `inspect_firmware_regions`, `extract_firmware` and the
24 ADB device tools then work. Browser tools need a CDP endpoint on loopback;
the helper script forwards one from another machine. See
[docs/platform-support.md](docs/platform-support.md) for the full support
matrix covering Android/arm64, macOS and iOS, including what cannot be
installed on a phone. macOS setup is in `platform/macos/setup.sh` (run on a Mac).

After changing provider settings, **restart OpenCode** so the MCP server picks
up the new environment.

---

## How the arm64 magic works (short version)

1. **Ghidra's release only ships x86-64 decompiler code.** On arm64 the Java side runs
   but decompiling fails. Fix: compile Ghidra's decompiler from source for arm64 with
   Termux's `clang/g++` and drop it into `Ghidra/Features/Decompiler/os/linux_arm_64/`.
   (`toolchain/build-decompiler.sh` does this.)
2. **REA checks `process.platform === "linux"`** for its engine providers, but Node on
   Android reports `"android"`. Fix: a 10-line shim in REA's launcher makes it see
   `"linux"` (`toolchain/rea-android-shim.cjs`, applied by `install.sh`).
3. **JADX needs a specific bridge JAR.** `install.sh` downloads the version REA pins
   (0.7.1) and verifies its SHA-256.

That's it. Everything else is standard `pkg`/`npm` installs.

---

## Project layout

```
rea/                       ← inside rea-goldfish-android-arm64
├── README.md              ← you are here
├── LICENSE                ← MIT (this repo only)
├── CONTRIBUTING.md        ← how to help
├── CHANGELOG.md
├── Makefile               ← make install / verify / uninstall
├── scripts/
│   ├── install.sh         ← one-shot installer (idempotent)
│   ├── verify.sh          ← health check
│   └── uninstall.sh       ← undo
├── toolchain/
│   ├── rea-env.sh         ← environment variables
│   ├── rea-android-shim.cjs
│   ├── build-decompiler.sh
│   ├── wrappers/          ← kuna, jadx, ghidra-headless
│   └── ghidra/decompiler/ ← placeholder (built by install.sh)
└── patches/
    └── rea.mjs            ← reference copy of the patched REA launcher
```

---

## Troubleshooting

- **`rea: command not found`** → `npm i -g rea-agents@6.9.0`, then restart your shell.
- **`ghidra-native_decompiler` fails in `rea doctor`** → re-run `bash scripts/install.sh`
  (it rebuilds the decompiler) or run `bash toolchain/build-decompiler.sh`.
- **JADX JAR SHA mismatch** → delete `~/tools/jadx-mcp/*.jar` and re-run the installer.
- **`aapt`/`aapt2` "attribute not found"** → you need a framework jar; the installer
  fetches `android-34.jar` into `~/tools/android-build/`.
- **OpenCode shows no REA tools** → fully close and reopen OpenCode after installing.

---

## Uninstall

```bash
bash scripts/uninstall.sh
# then optionally:
pkg uninstall jadx apktool dex2jar rizin radare2 binutils aapt aapt2 apksigner
npm uninstall -g rea-agents
```

---

## Credits & licenses

- [REA](https://github.com/morluto/rea) — reverse-engineering agent (its own license).
- [Ghidra](https://github.com/NationalSecurityAgency/ghidra) — Apache-2.0.
- [JADX](https://github.com/skylot/jadx) — Apache-2.0; [jadx-headless-mcp](https://github.com/1013503897/jadx-headless-mcp) — Apache-2.0.
- [Kuna](https://github.com/Noelo-Lab/kuna) — Apache-2.0.
- apktool, dex2jar, rizin, radare2 — GPL/Apache.
- This repository: **MIT** (installation glue + docs only).

If this project helped you, consider starring it on GitHub. ⭐