<!-- Copyright 2026. SPDX-License-Identifier: MIT for this guide; EGM content is Apache-2.0. -->

# EGM on OpenCode v2 / Android (Termux, arm64)

This bundle is the **official** [Elephant-Goldfish Model](https://github.com/google/elephant-goldfish-model)
assets (Google LLC, Apache-2.0), installed by `egm-android-arm64`. Upstream's
`adapters/opencode` targets OpenCode V1 (1.18.29); this installation targets the
OpenCode v2 config format used on Termux/arm64.

## Paths

All bundle paths written into skills and agents are absolute:

- Bundle root: see `EGM bundle root:` in the loaded skill or agent
- Personas: `<bundle>/agents/`
- Standards: `<bundle>/resources/`
- Integration notes: `<bundle>/docs/opencode.md` (this file)

User files, briefs, drafts and reports stay in the **project working directory**
unless the prompt or `AGENTS.md` contains `EGM artifact directory: <path>`.

## Tools and delegation

| Need | Use |
| --- | --- |
| Fresh Goldfish reviewer | `subagent` tool with `subagent_type: <egm-persona>` |
| Main workflow agent | `egm` (primary agent), or `/egm-*` commands |
| Approval gate | `question` tool — one question at a time, continue after it returns |
| Discover skill | `skill` tool with the canonical id (e.g. `egm-review`) |

OpenCode v2 subagents always run in child sessions with fresh context — that is
the Goldfish property EGM needs. The primary agent must wait for each child and
write reports itself. Never simulate a reviewer in the parent conversation.

Reviewer personas are read-only: `read`, `grep`, `glob` and `list` only. The
synthesizer may write reports and spawn reviewers; the bootstrap orchestrator
may also run shell commands. Delegation is restricted to the registered personas.
`experimental.subagent_depth` is set to at least 2 in `opencode.json` so nested
bootstrap/synthesis delegation works.

## Commands

After a restart, these commands are available:

`/egm-brainstorm`, `/egm-draft`, `/egm-review`, `/egm-review-loop`,
`/egm-resolve`, `/egm-bootstrap`, `/egm-drift-report`, `/egm-lite`.

You can also ask in ordinary chat: “Use the egm-review skill to review
`/absolute/path/design.md`.” Do not paste untrusted material into slash-command
arguments — OpenCode evaluates shell markers before tool permissions apply.

## Verification limits

Registration is not workflow verification. A fresh child session plus read-only
tool rules is not process isolation. A review does not replace tests or human
judgment. Confirm the effective configuration with `opencode debug agents` and
`opencode debug config`, and run `bash scripts/verify.sh` in the setup project.
