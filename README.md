# REA + Goldfish (EGM) on Android — arm64

**One open-source project, two workflows, on a Termux phone.**

| Component | What it gives you |
| --- | --- |
| **`rea/`** — [REA](https://github.com/morluto/rea) on Android/arm64 | Reverse engineering: Ghidra 12.1.3 (arm64 decompiler), JADX 1.5.6, Kuna 1.990, apktool, dex2jar, aapt, rizin. Exposes 255 tools to OpenCode. |
| **`egm/`** — [Elephant-Goldfish Model](https://github.com/google/elephant-goldfish-model) on Android/arm64 | Design & review: 8 skills, 10 fresh-context Goldfish reviewer personas, and an `egm` orchestrator agent in OpenCode v2. |

> **Relationship to the older GitHub project:** the REA-only version was previously uploaded to GitHub **without Goldfish**. This repository is the merged successor: it keeps the latest REA setup (including optional providers, browser/CDP and macOS platform docs) **and** adds the official EGM/Goldfish bundle, adapted to work with the OpenCode v2 installed on this device.

Everything here is **installation glue and documentation** — no proprietary tools, no cracked software. Upstream projects keep their own licenses (see [ATTRIBUTION.md](ATTRIBUTION.md)).

## Requirements

- Android device, **arm64 / aarch64**, with Termux from F-Droid or GitHub (no root).
- `python3`, `node`, `npm`, `openjdk-21`, `git` — all installed by the scripts via `pkg`/`npm`.
- ~1.5 GB free space (Ghidra ≈ 550 MB plus build tools).
- OpenCode v2 (the EGM installer targets v2; REA's MCP server works with it).

## Quick start

```bash
git clone https://github.com/a1computerinc2026/rea-goldfish-android-arm64.git
cd rea-goldfish-android-arm64
bash scripts/install-all.sh
bash scripts/verify-all.sh       # want healthy: true for both
```

Then **fully restart OpenCode** so it loads the REA MCP server and the EGM skills/agents.

### Install only one component

```bash
bash rea/scripts/install.sh      # or: make rea-install
bash egm/scripts/install.sh      # or: make egm-install
```

## Use

**Reverse engineering (REA)** — after restart, just ask OpenCode:

```text
Decompile ~/Download/libtarget.so with Ghidra and explain the main function.
Inspect ~/Download/app.apk: manifest, classes and signature.
```

Or from Termux:

```bash
. ~/.rea-env.sh
rea analyze libtarget.so --provider ghidra --format json
```

**Design / review (Goldfish)** — select the `egm` agent or use a slash command:

```text
/egm-brainstorm Add offline export to the app.
/egm-draft
/egm-review design_draft.md
/egm-drift-report docs/designs/
```

## Layout

```text
rea-goldfish-android-arm64/
├── README.md                 ← you are here
├── ATTRIBUTION.md            # upstream licenses & credits
├── LICENSE                   # MIT (installation glue only)
├── Makefile                  # make install / verify / uninstall
├── scripts/
│   ├── install-all.sh        # install both components
│   ├── verify-all.sh         # verify both components
│   └── uninstall-all.sh
├── rea/                      # latest REA setup (from rea-android-arm64)
│   ├── README.md             # full REA docs, troubleshooting, usage
│   ├── scripts/              # install.sh, verify.sh, uninstall.sh, optional providers
│   ├── toolchain/            # env, shim, arm64 decompiler build, wrappers
│   ├── docs/                 # platform support matrix
│   ├── platform/macos/       # macOS setup (not usable on a phone)
│   └── patches/
└── egm/                      # official EGM (Goldfish) bundle
    ├── README.md             # full EGM docs
    ├── scripts/              # install.sh, verify.sh, uninstall.sh
    ├── toolchain/            # egm-env.sh, V2 installer + verifier (Python stdlib)
    ├── overlay/docs/         # OpenCode v2 / Android integration guide
    └── vendor/egm/           # unmodified official EGM assets + SOURCE_COMMIT
```

## Verification

```bash
bash rea/scripts/verify.sh   # healthy: true + OK on ghidra/jadx/kuna
bash egm/scripts/verify.sh   # healthy: true + skills/agents/commands live
```

Both checks are non-destructive and can be run any time. EGM's installer merges
into `opencode.json` additively and verifies the REA MCP entry survives; its
uninstaller restores the previous config and any legacy plugin from a timestamped
backup under `~/.local/share/egm-android-arm64/backups/`.

## Publishing to GitHub

This folder is already a Git repository containing the original REA commit plus
the merged update. GitHub username: `a1computerinc2026`.

**Option A — publish as a new repository (recommended):**

```bash
cd rea-goldfish-android-arm64
git remote add origin https://github.com/a1computerinc2026/rea-goldfish-android-arm64.git
git branch -M main
git push -u origin main
```

**Option B — update your existing REA-only repository** (only if its history
matches this repo's history; otherwise use Option A):

```bash
cd rea-goldfish-android-arm64
git remote add origin https://github.com/a1computerinc2026/rea-android-arm64.git
git push origin master
```

Create the GitHub repository as **public** with **no** README/LICENSE added by
GitHub (this repo already has them).

## Limitations

- Tool registration/health checks are not proof of a full workflow; model calls
  need your authorization, and reviews do not replace tests or human judgment.
- OpenCode v2 subagents are isolated child *sessions*, not process isolation.
- Ghidra's decompiler is built locally from source for arm64; JADX/Kuna/REA keep
  their own licenses. EGM is not an officially supported Google product.

## Credits

See [ATTRIBUTION.md](ATTRIBUTION.md). This repository's glue code is MIT.
