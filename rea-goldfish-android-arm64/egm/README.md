# EGM (Goldfish) on Android (Termux, arm64)

> **This is the `egm/` component of the merged [`rea-goldfish-android-arm64`](../README.md) project.** From the merged repository root, run `bash egm/scripts/install.sh` and `bash egm/scripts/verify.sh`.

> This is an **Android/arm64 installer for [Google's Elephant-Goldfish Model](https://github.com/google/elephant-goldfish-model)** (EGM), not EGM itself. The official EGM assets are vendored unchanged under `vendor/egm/` (Apache-2.0, Copyright Google LLC). The installer glue here is MIT.

EGM is an open-source plugin for AI coding agents: **Elephant** drafts a design with full project context, **Goldfish** reviewers examine it with *fresh* subagent contexts, and **you** approve the design. There is no native binary to compile — EGM is Markdown skills, agent personas and standards. The work here is making the **official** bundle load correctly in **OpenCode v2 on Termux/arm64**, alongside the REA MCP server.

## Why a custom installer?

| Problem on this device | Fix in this repo |
| --- | --- |
| Upstream `adapters/opencode/install.py` targets **OpenCode V1** (1.18.29) JSON interfaces (`permission`, `task`). Device has **OpenCode v2.0.25** (`permissions`, `subagent`). | Generate V2-native agent files and commands from the canonical upstream frontmatter. |
| V1 installer uses **symlinks** for skill aliases; Android shared storage (`/sdcard`) has no symlink support. | Install into `$HOME/.local/share/...` (Termux filesystem) and use **regular files**. |
| A third-party `opencode-egm` npm plugin may already be registered, duplicating/conflicting with the official skills. | Back it up and retire it, so only the official bundle is loaded. |
| Existing `opencode.json` contains the REA MCP config. | Merge settings additively; back up and verify REA is preserved. |

No root required. Python 3 standard library only — nothing to cross-compile for arm64.

## Requirements

- Android device (arm64/aarch64) with Termux from F-Droid/GitHub.
- `python3` (`pkg install python`), `opencode` v2 (`npm i -g opencode-ai`), `git`.
- ~5 MB free (the vendored docs/assets are small).

## Install

```bash
cd egm                          # from the merged repository root
bash scripts/install.sh
bash scripts/verify.sh        # want "healthy: true"
```

Then **fully restart OpenCode** so it discovers the new skills, agents and commands.

## Use

Select the `egm` primary agent (or run a slash command):

```text
/egm-brainstorm Add offline export to the app.
/egm-draft
/egm-review design_draft.md
```

Or in ordinary chat: *"Use the `egm-drift-report` skill on `docs/designs/`."*

Commands installed: `/egm-brainstorm`, `/egm-draft`, `/egm-review`,
`/egm-review-loop`, `/egm-resolve`, `/egm-bootstrap`, `/egm-drift-report`, `/egm-lite`.

For gate prompts the installer adapts skills to OpenCode v2's `question` tool and
`subagent` tool; see `overlay/docs/opencode.md` (copied into the bundle as
`docs/opencode.md`).

## Layout

```text
egm/                           ← inside rea-goldfish-android-arm64
├── README.md
├── LICENSE                 # MIT glue; upstream EGM is Apache-2.0
├── Makefile                # make install / verify / uninstall
├── scripts/
│   ├── install.sh          # wrapper
│   ├── verify.sh           # health check (healthy: true)
│   └── uninstall.sh        # restore previous config/plugin
├── toolchain/
│   ├── egm-env.sh          # paths
│   ├── install_egm.py      # V2 adapter + installer (stdlib only)
│   └── verify_egm.py       # checks
├── overlay/docs/opencode.md# V2/Android integration guide
└── vendor/egm/             # unmodified official EGM assets + SOURCE_COMMIT
```

## Verify / uninstall

```bash
bash scripts/verify.sh
bash scripts/uninstall.sh
```

Uninstall removes only managed files whose hashes still match, restores the prior
`opencode.json` and the legacy plugin symlink, and deletes the bundle. Backups of
overwritten files are under `~/.local/share/egm-android-arm64/backups/<timestamp>/`.

## Limitations

- OpenCode v2 subagents always run in child sessions with fresh context — this is
  the desired Goldfish property, but tool rules are not process isolation.
- Installation and verification do not prove a full review workflow; model calls
  require your authorization. Reviews do not replace tests or human judgment.
- Upstream EGM is not an officially supported Google product.

## Credits

- [Elephant-Goldfish Model](https://github.com/google/elephant-goldfish-model) — Google LLC, Apache-2.0.
- [OpenCode](https://opencode.ai) v2 — agent host.
- This installer glue — MIT.
