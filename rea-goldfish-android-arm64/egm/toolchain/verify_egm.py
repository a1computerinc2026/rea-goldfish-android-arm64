#!/usr/bin/env python3
"""Health checks for the EGM Android/arm64 installation."""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

BUNDLE = Path(os.environ.get("EGM_BUNDLE_DIR", str(Path.home() / ".local/share/egm-android-arm64/bundle")))
CONFIG = Path(os.environ.get("OPENCODE_CONFIG_DIR", str(Path.home() / ".config/opencode")))
STATE = BUNDLE.parent

SKILLS = [
    "egm-bootstrap", "egm-brainstorm", "egm-draft", "egm-drift-report",
    "egm-lite", "egm-resolve", "egm-review", "egm-review-loop",
]
AGENTS = [
    "egm-bootstrap-orchestrator", "egm-codebase-details", "egm-comprehension",
    "egm-design", "egm-implementation-readiness", "egm-inventive-catalyst",
    "egm-structural", "egm-style", "egm-synthesizer", "egm-zoom-out",
]
COMMANDS = SKILLS

failures: list[str] = []


def check(ok: bool, name: str, detail: str = "") -> None:
    print(f"  {'OK  ' if ok else 'FAIL'} {name}" + (f": {detail}" if detail else ""))
    if not ok:
        failures.append(name)


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


print("== manifest ==")
manifest_path = STATE / "installation.json"
if not manifest_path.exists():
    check(False, "manifest", "not found — run scripts/install.sh")
    print("healthy: false")
    sys.exit(1)
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
check(True, "egm-version", f"{manifest.get('egm_version')} @ {str(manifest.get('source_commit'))[:12]}")
check(True, "arch", str(manifest.get("arch")))
check(True, "opencode-version", str(manifest.get("opencode_version")))

print("== bundle ==")
hashes = manifest.get("bundle_sha256", {})
bad = [rel for rel, digest in hashes.items()
       if not (BUNDLE / rel).is_file() or sha(BUNDLE / rel) != digest]
check(not bad and bool(hashes), "bundle-integrity", f"{len(hashes)} files, {len(bad)} changed/missing")

print("== registration ==")
for sid in SKILLS:
    p = CONFIG / "skills" / sid / "SKILL.md"
    check(p.is_file() and str(BUNDLE) in p.read_text(encoding="utf-8", errors="ignore"), f"skill:{sid}")
for aid in AGENTS:
    p = CONFIG / "agents" / f"{aid}.md"
    text = p.read_text(encoding="utf-8", errors="ignore") if p.is_file() else ""
    check(p.is_file() and "mode: subagent" in text and "permissions:" in text, f"agent:{aid}")
p = CONFIG / "agents" / "egm.md"
check(p.is_file() and "mode: primary" in p.read_text(encoding="utf-8", errors="ignore"), "agent:egm")
for cmd in COMMANDS:
    check((CONFIG / "commands" / f"{cmd}.md").is_file(), f"command:{cmd}")
check(not (CONFIG / "plugins" / "opencode-egm").exists(), "legacy-plugin-retired")

print("== opencode ==")
try:
    raw = subprocess.run(["opencode", "debug", "agents"], capture_output=True, text=True,
                         timeout=90).stdout
    live = {item.get("id") for item in json.loads(raw)}
    missing = [a for a in AGENTS + ["egm"] if a not in live]
    check(not missing, "live-agents",
          "all registered" if not missing else f"missing {missing} — run `opencode reload` or restart OpenCode")
except (OSError, subprocess.SubprocessError, json.JSONDecodeError) as exc:
    check(False, "live-agents", str(exc))

try:
    raw = subprocess.run(["opencode", "debug", "config"], capture_output=True, text=True,
                         timeout=90).stdout
    sources = json.loads(raw)
    merged: dict = {}
    for src in sources:
        info = src.get("info", {})
        for key, value in info.items():
            if isinstance(value, dict) and isinstance(merged.get(key), dict):
                merged[key].update(value)
            else:
                merged[key] = value
    depth = merged.get("experimental", {}).get("subagent_depth", 0)
    check(int(depth) >= 2, "subagent-depth", str(depth))
    rea = merged.get("mcp", {}).get("servers", {}).get("rea") or merged.get("mcp", {}).get("rea")
    check(bool(rea), "rea-mcp-preserved")
except (OSError, subprocess.SubprocessError, json.JSONDecodeError) as exc:
    check(False, "config", str(exc))

print(f"healthy: {'false' if failures else 'true'}")
sys.exit(1 if failures else 0)
