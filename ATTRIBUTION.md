# Attribution and licenses

This repository contains **installation glue and documentation only**. It does
not redistribute proprietary tools. Each upstream project keeps its own license.

## Bundled / vendored content

| Component | Upstream | License | Location |
| --- | --- | --- | --- |
| Elephant-Goldfish Model (official skills, personas, standards) | [google/elephant-goldfish-model](https://github.com/google/elephant-goldfish-model) | Apache-2.0, Copyright Google LLC | `egm/vendor/egm/` (full text: `egm/vendor/egm/LICENSE`) |
| REA installer glue (original) | this project | MIT | `rea/` |

The EGM bundle is vendored **unmodified** from upstream commit recorded in
`egm/vendor/egm/SOURCE_COMMIT`. The OpenCode v2 adapter in `egm/toolchain/` and
the Android-specific docs are MIT-licensed glue written for this repository.

## Downloaded at install time (not redistributed here)

| Tool | License | Source |
| --- | --- | --- |
| REA (`rea-agents`) | see upstream | npm `rea-agents@6.9.0` |
| Ghidra 12.1.3 | Apache-2.0 | National Security Agency |
| JADX 1.5.6 | Apache-2.0 | skylot |
| jadx-headless-mcp 0.7.1 | Apache-2.0 | 1013503897 |
| Kuna 1.990 | Apache-2.0 | Noelo-Lab |
| apktool | Apache-2.0 | iBotPeaches |
| dex2jar | Apache-2.0 | pxb1988 |
| aapt / aapt2 | Apache-2.0 | Android Open Source Project |
| rizin / radare2 | LGPL/GPL | rizinorg |
| binutils, OpenJDK 21 | GPL / GPL+CE | Free Software Foundation / Oracle/OpenJDK |
| OpenCode v2 | MIT | opencode.ai |

Not included: IDA Pro, Hopper, and other proprietary commercial tools — they
cannot legally be installed or redistributed here.

## Trademarks

Ghidra is a trademark of the NSA. Android is a trademark of Google LLC.
This project is not affiliated with or endorsed by Google, the NSA, or the REA
maintainers. EGM is not an officially supported Google product.
