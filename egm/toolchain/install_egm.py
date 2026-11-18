#!/usr/bin/env python3
# Copyright 2026. SPDX-License-Identifier: MIT (this installer).
# The bundled EGM assets are Copyright Google LLC, Apache-2.0 (see vendor/egm/LICENSE).
"""Install the official EGM asset bundle into OpenCode v2 on Termux / Android arm64.

Why a custom installer?
  * Upstream's adapters/opencode/install.py targets OpenCode V1 (1.18.29) and uses
    JSONC `permission`/`task` keys that V2 replaced with `permissions`/`subagent`.
  * Termux's shared storage (/sdcard) has no symlinks, so the V1 installer's
    symlink-based skill aliases cannot live there. We install into $HOME and use
    regular files instead.
  * It must coexist with the REA MCP server already registered in OpenCode.

Only the Python standard library is used, so this runs on stock Termux arm64.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / "vendor" / "egm"
OVERLAY = ROOT / "overlay"


# --------------------------------------------------------------------------- helpers

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def q(value: str) -> str:
    """JSON double-quoted string is also a valid YAML double-quoted scalar."""
    return json.dumps(str(value), ensure_ascii=False)


def parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    """Parse the small YAML frontmatter subset used by EGM (no PyYAML needed)."""
    text = text.replace("\r\n", "\n")
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end < 0:
        return {}, text
    lines = text[4:end].split("\n")
    body = text[end + 5:]
    attrs: dict[str, str] = {}
    i = 0
    while i < len(lines):
        line = lines[i]
        match = re.match(r"^([A-Za-z0-9_-]+):[ \t]*(.*)$", line)
        if not match:
            i += 1
            continue
        key, raw = match.group(1), match.group(2).strip()
        if raw in (">", ">-", "|", "|-"):
            block: list[str] = []
            i += 1
            while i < len(lines) and (lines[i].startswith((" ", "\t")) or lines[i] == ""):
                block.append(lines[i].strip())
                i += 1
            sep = " " if raw.startswith(">") else "\n"
            attrs[key] = sep.join(part for part in block if part).strip()
            continue
        attrs[key] = raw.strip("'\"")
        i += 1
    return attrs, body


def rewrite_paths(text: str, bundle: Path, skill_dir: Path | None = None) -> str:
    """Repoint harness-portable EGM references at the installed bundle."""
    b = str(bundle)
    text = text.replace("${CLAUDE_PLUGIN_ROOT}/docs/claude.md", f"{b}/docs/opencode.md")
    text = text.replace("${CLAUDE_PLUGIN_ROOT}/docs/codex.md", f"{b}/docs/opencode.md")
    text = text.replace("${CLAUDE_PLUGIN_ROOT}", b)
    text = re.sub(r"\.\./\.\./docs/[A-Za-z0-9_.-]+\.md", f"{b}/docs/opencode.md", text)
    text = re.sub(r"(?<![\w/])docs/(?:harnesses|claude|codex|opencode)\.md",
                  f"{b}/docs/opencode.md", text)
    text = re.sub(r"(?<![\w/])agents/", f"{b}/agents/", text)
    text = re.sub(r"(?<![\w/])resources/", f"{b}/resources/", text)
    if skill_dir is not None:
        text = text.replace("(references/", f"({skill_dir}/references/")
        text = text.replace("`references/", f"`{skill_dir}/references/")
    return text


def yaml_permissions(role: str, bundle: Path, personas: list[str]) -> str:
    """OpenCode V2 permission rules for an agent (last matching rule wins)."""
    rules: list[tuple[str, str, str]] = [
        ("*", "*", "deny"),
        ("read", "*", "allow"),
        ("grep", "*", "allow"),
        ("glob", "*", "allow"),
        ("list", "*", "allow"),
        ("read", "*.env", "deny"),
        ("read", "*.env.*", "deny"),
        ("read", "*.env.example", "allow"),
        ("external_directory", str(bundle) + "/**", "allow"),
    ]
    if role in ("synthesizer", "bootstrap"):
        rules.append(("subagent", "*", "deny"))
        rules.extend(("subagent", persona, "allow") for persona in personas)
    if role == "synthesizer":
        rules.extend([("write", "*", "allow"), ("edit", "*", "allow")])
    if role == "bootstrap":
        rules.extend([("write", "*", "allow"), ("edit", "*", "allow"), ("bash", "*", "allow")])
    return "\n".join(
        f"    - action: {q(action)}\n      resource: {q(resource)}\n      effect: {q(effect)}"
        for action, resource, effect in rules
    )


def make_agent_file(attrs: dict[str, str], body: str, role: str, bundle: Path,
                    personas: list[str]) -> str:
    name = attrs.get("name", "egm-agent")
    title = name.replace("egm-", "").replace("-", " ").title()
    front = "\n".join([
        "---",
        f"name: {q(title)}",
        f"description: {q(attrs.get('description', 'EGM persona.'))}",
        "license: Apache-2.0",
        "mode: subagent",
        "hidden: false",
        "permissions:",
        yaml_permissions(role, bundle, personas),
        "---",
        "",
    ])
    return front + body.lstrip("\n")


def make_orchestrator_file(bundle: Path, personas: list[str]) -> str:
    context = (
        f"EGM Android bundle root: `{bundle}`. Resolve `agents/`, `resources/` and `docs/` "
        f"against this root. Resolve skill `references/` against the canonical skill directory. "
        f"Resolve user files and artifacts against the project working directory."
    )
    dispatch = "\n".join(f"- `{persona}`" for persona in personas)
    rules = [
        ("*", "*", "ask"),
        ("read", "*", "allow"),
        ("read", "*.env", "ask"),
        ("read", "*.env.*", "ask"),
        ("read", "*.env.example", "allow"),
        ("glob", "*", "allow"),
        ("grep", "*", "allow"),
        ("external_directory", "*", "ask"),
        ("external_directory", str(bundle) + "/**", "allow"),
        ("skill", "*", "deny"),
        ("skill", "egm-*", "allow"),
        ("subagent", "*", "deny"),
    ]
    rules.extend(("subagent", persona, "allow") for persona in personas)
    perm = "\n".join(
        f"    - action: {q(a)}\n      resource: {q(r)}\n      effect: {q(e)}" for a, r, e in rules
    )
    front = "\n".join([
        "---",
        "name: EGM Orchestrator",
        "description: Runs the Elephant-Goldfish design/review workflows with fresh Goldfish subagents.",
        "license: Apache-2.0",
        "mode: primary",
        "permissions:",
        perm,
        "---",
        "",
    ])
    body = "\n".join([
        "# EGM orchestrator (OpenCode v2 / Android arm64)",
        "",
        context,
        "",
        "## Delegation",
        "",
        "Follow the canonical EGM skill you loaded. Dispatch each Goldfish as a fresh",
        "child session with the `subagent` tool and `subagent_type` set to one of:",
        "",
        dispatch,
        "",
        "Pass only the task, absolute bundle paths, the target, standards and the",
        "explicitly selected reading list. Never pass conversation history, private",
        "reasoning or unsolicited memory. Do not reuse or resume a reviewer session.",
        "Wait for each child to finish before synthesizing; report a missing child as",
        "an incomplete review. Never simulate a Goldfish in the parent conversation.",
        "",
        "For brainstorm, finish all seven reviewers and write `concepts_brief.md` before",
        "drafting. For review, write each stage report before starting the next stage;",
        "before Step 8 verify `zoom_out_report.md` exists and pass its absolute path.",
        "",
        "Use the `question` tool for every approval gate, including open-ended input.",
        "Send exactly one question at a time and continue the workflow after it returns.",
        "Artifacts go to the project working directory unless the prompt or AGENTS.md",
        "specifies `EGM artifact directory: <path>`. Preserve every human approval gate.",
        "",
    ])
    return front + body


def skill_preamble(bundle: Path, skill_dir: Path, personas: list[str]) -> str:
    persona_list = ", ".join(f"`{p}`" for p in personas)
    return "\n".join([
        "> **EGM on OpenCode v2 (Android/arm64).** Bundle root: "
        f"`{bundle}`.",
        ">",
        f"> - **Subagents:** launch each Goldfish with the `subagent` tool and `subagent_type` "
        f"set to one of {persona_list}. A launch creates a fresh child session. Pass only the "
        "task, absolute resource paths, target, standards and selected reading list — never "
        "this conversation or the parent's reasoning. Wait for completion; never fake a review.",
        "> - **Gates:** use the `question` tool for every approval gate, including open-ended "
        "input. Offer one plausible option; the user can type a free-form answer. Continue in "
        "the same turn after the tool returns.",
        "> - **Artifacts:** write briefs/drafts/reports into the project working directory, or "
        "into `EGM artifact directory: <path>` when specified. Do not dump large artifacts into chat.",
        f"> - **Paths:** all bundle paths are absolute. Resolve `references/...` against "
        f"`{skill_dir}`. OpenCode docs: `{bundle}/docs/opencode.md`.",
        "",
    ])


def command_file(name: str, skill: str, description: str, bundle: Path) -> str:
    return "\n".join([
        "---",
        f"description: {q(description)}",
        "---",
        f"The user invoked /{name}. Read and execute the `{skill}` skill.",
        f"If the skill attachment did not load, read `{bundle}/skills/{skill}/SKILL.md` and follow it.",
        "Use the `question` tool for every gate and dispatch fresh-context Goldfish reviewers",
        "with the `subagent` tool. Keep artifacts in the project directory.",
        "",
        "User request: $ARGUMENTS",
        "",
    ])


# --------------------------------------------------------------------------- manifest

def load_manifest(state: Path) -> dict | None:
    path = state / "installation.json"
    if path.exists():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return None
    return None


def write_managed(path: Path, text: str, backups: Path, managed: list[str],
                  config_root: Path) -> None:
    """Write a managed file, backing up any different pre-existing file first."""
    if path.exists() and not path.is_symlink() and sha256_file(path) == sha256_text(text):
        managed.append(path.relative_to(config_root).as_posix())
        return
    if path.exists() or path.is_symlink():
        backup = backups / path.relative_to(config_root)
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(path), str(backup))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    managed.append(path.relative_to(config_root).as_posix())


# --------------------------------------------------------------------------- install

def install(bundle: Path, config: Path, force: bool) -> int:
    if not (VENDOR / "skills" / "egm-review" / "SKILL.md").exists():
        print(f"error: vendored EGM assets missing under {VENDOR}", file=sys.stderr)
        return 2

    state = bundle.parent
    now = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backups = state / "backups" / now
    state.mkdir(parents=True, exist_ok=True)

    plugin_meta = json.loads((VENDOR / "plugin.json").read_text(encoding="utf-8"))
    version = plugin_meta.get("version", "unknown")
    commit = (VENDOR / "SOURCE_COMMIT").read_text(encoding="utf-8").strip()

    # 1. Copy the unmodified upstream bundle into Termux's own filesystem.
    for directory in ("skills", "agents", "resources", "docs"):
        shutil.copytree(VENDOR / directory, bundle / directory, dirs_exist_ok=True)
    for filename in ("plugin.json", "LICENSE", "README.md", "SOURCE_COMMIT"):
        shutil.copy2(VENDOR / filename, bundle / filename)
    # Override upstream's V1 OpenCode guide with our V2/Android guide.
    shutil.copy2(OVERLAY / "docs" / "opencode.md", bundle / "docs" / "opencode.md")

    # 2. Discover personas and skills from the canonical frontmatter.
    personas: list[str] = []
    persona_roles: dict[str, str] = {}
    role_by_file = {
        "bootstrap_orchestrator.md": "bootstrap",
        "synthesizer.md": "synthesizer",
    }
    for agent_file in sorted((VENDOR / "agents").glob("*.md")):
        attrs, _ = parse_frontmatter(agent_file.read_text(encoding="utf-8"))
        pid = attrs.get("name") or f"egm-{agent_file.stem}"
        personas.append(pid)
        persona_roles[pid] = role_by_file.get(agent_file.name, "reviewer")

    skill_dirs = sorted(p for p in (VENDOR / "skills").iterdir()
                        if (p / "SKILL.md").exists())
    skill_ids = []
    for sdir in skill_dirs:
        attrs, _ = parse_frontmatter((sdir / "SKILL.md").read_text(encoding="utf-8"))
        skill_ids.append(attrs.get("name") or sdir.name)

    managed: list[str] = []

    # 3. Install adapted skills (regular files, no symlinks — /sdcard-safe).
    for sdir, sid in zip(skill_dirs, skill_ids):
        attrs, body = parse_frontmatter((sdir / "SKILL.md").read_text(encoding="utf-8"))
        installed_dir = config / "skills" / sdir.name
        installed_dir.mkdir(parents=True, exist_ok=True)
        # Copy supporting files (references/, assets/, templates, etc.).
        for child in sdir.iterdir():
            if child.name == "SKILL.md":
                continue
            dest = installed_dir / child.name
            if child.is_dir():
                shutil.copytree(child, dest, dirs_exist_ok=True)
            else:
                shutil.copy2(child, dest)
        header_lines = ["---"]
        for key in ("name", "license", "disable-model-invocation", "description"):
            if key in attrs:
                header_lines.append(f"{key}: {q(attrs[key])}")
        header_lines += ["---", ""]
        content = "\n".join(header_lines)
        content += skill_preamble(bundle, installed_dir, personas)
        content += rewrite_paths(body, bundle, installed_dir)
        write_managed(installed_dir / "SKILL.md", content, backups, managed, config)

    # 4. Install reviewer personas as OpenCode v2 subagents.
    legacy_agents = [
        "bootstrap_orchestrator.md", "codebase_details.md", "comprehension.md",
        "design_critic.md", "goldfish_explorer.md", "implementation_readiness.md",
        "inventive_catalyst.md", "structural.md", "style.md", "synthesizer.md", "zoom_out.md",
    ]
    for filename in legacy_agents:
        legacy = config / "agents" / filename
        if legacy.exists() or legacy.is_symlink():
            backup = backups / "agents" / filename
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(legacy), str(backup))

    for agent_file in sorted((VENDOR / "agents").glob("*.md")):
        attrs, body = parse_frontmatter(agent_file.read_text(encoding="utf-8"))
        pid = attrs.get("name") or f"egm-{agent_file.stem}"
        content = make_agent_file(attrs, rewrite_paths(body, bundle),
                                  persona_roles[pid], bundle, personas)
        write_managed(config / "agents" / f"{pid}.md", content, backups, managed, config)

    write_managed(config / "agents" / "egm.md",
                  make_orchestrator_file(bundle, personas), backups, managed, config)

    # 5. Install slash commands.
    commands = []
    for sid, sdir in zip(skill_ids, skill_dirs):
        attrs, _ = parse_frontmatter((sdir / "SKILL.md").read_text(encoding="utf-8"))
        desc = attrs.get("description", f"Run {sid}.").replace("\n", " ")
        commands.append((sid, sid, desc[:180]))
    for name, skill, desc in commands:
        write_managed(config / "commands" / f"{name}.md",
                      command_file(name, skill, desc, bundle), backups, managed, config)

    # 6. Retire the old third-party `opencode-egm` plugin so it cannot register
    #    a second, conflicting copy of the same skills/agents.
    legacy_plugin = None
    plugin_path = config / "plugins" / "opencode-egm"
    if plugin_path.exists() or plugin_path.is_symlink():
        target = None
        if plugin_path.is_symlink():
            target = os.readlink(plugin_path)
        backup = backups / "plugins" / "opencode-egm"
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(plugin_path), str(backup))
        legacy_plugin = {
            "original": str(plugin_path),
            "backup": str(backup),
            "symlink_target": target,
        }

    # 7. Merge settings into opencode.json without disturbing REA's MCP entry.
    settings_path = config / "opencode.json"
    settings: dict = {}
    if settings_path.exists():
        try:
            settings = json.loads(settings_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            backup = backups / "opencode.json"
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(settings_path, backup)
            print("warning: opencode.json was not JSON; replaced with a fresh config", file=sys.stderr)
            settings = {}
    experimental = settings.setdefault("experimental", {})
    experimental["subagent_depth"] = max(int(experimental.get("subagent_depth", 1)), 2)
    new_settings = json.dumps(settings, indent=2, ensure_ascii=False) + "\n"
    if not settings_path.exists() or settings_path.read_text(encoding="utf-8") != new_settings:
        if settings_path.exists():
            backup = backups / "opencode.json"
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(settings_path, backup)
        settings_path.parent.mkdir(parents=True, exist_ok=True)
        settings_path.write_text(new_settings, encoding="utf-8")

    # 8. Manifest for verification / uninstall.
    bundle_hashes = {
        path.relative_to(bundle).as_posix(): sha256_file(path)
        for path in sorted(bundle.rglob("*")) if path.is_file()
    }
    arch = os.uname().machine
    try:
        oc_version = subprocess.run(["opencode", "--version"], capture_output=True,
                                    text=True, timeout=15).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        oc_version = "unknown"
    manifest = {
        "name": "egm-android-arm64",
        "egm_version": version,
        "source_commit": commit,
        "installed_at": now,
        "arch": arch,
        "opencode_version": oc_version,
        "bundle": str(bundle),
        "config": str(config),
        "bundle_sha256": bundle_hashes,
        "managed": managed,
        "managed_sha256": {
            rel: sha256_file(config / rel)
            for rel in managed if (config / rel).is_file()
        },
        "backups": str(backups),
        "legacy_plugin": legacy_plugin,
    }
    (state / "installation.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print("EGM installed successfully.")
    print(f"  EGM version      : {version} ({commit[:12]})")
    print(f"  Bundle           : {bundle}")
    print(f"  OpenCode config  : {config}")
    print(f"  Skills           : {len(skill_ids)} ({', '.join(skill_ids)})")
    print(f"  Personas         : {len(personas)}")
    print(f"  Commands         : {len(commands)}")
    print(f"  Backup           : {backups}")
    print("Restart OpenCode, then select the `egm` agent or run /egm-review.")
    return 0


# --------------------------------------------------------------------------- uninstall

def uninstall(bundle: Path, config: Path) -> int:
    manifest = load_manifest(bundle.parent)
    if manifest is None:
        print("error: no EGM installation manifest found", file=sys.stderr)
        return 2
    removed = 0
    for rel in manifest.get("managed", []):
        path = config / rel
        if path.is_file() and not path.is_symlink():
            if sha256_file(path) != manifest.get("managed_sha256", {}).get(rel):
                # Best effort: only remove files that still look like ours.
                if "EGM" not in path.read_text(encoding="utf-8", errors="ignore")[:2000]:
                    print(f"skip (modified): {path}")
                    continue
            path.unlink()
            removed += 1
            parent = path.parent
            while parent != config and parent.exists() and not any(parent.iterdir()):
                parent.rmdir()
                parent = parent.parent
    legacy = manifest.get("legacy_plugin")
    if legacy:
        backup = Path(legacy["backup"])
        if backup.exists() or backup.is_symlink():
            dest = Path(legacy["original"])
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(backup), str(dest))
            print(f"restored legacy plugin: {dest}")
    settings_backup = Path(manifest["backups"]) / "opencode.json"
    if settings_backup.exists():
        shutil.copy2(settings_backup, config / "opencode.json")
        print("restored previous opencode.json")
    shutil.rmtree(bundle, ignore_errors=True)
    (bundle.parent / "installation.json").unlink(missing_ok=True)
    print(f"removed {removed} managed file(s); bundle deleted: {bundle}")
    return 0


# --------------------------------------------------------------------------- entry

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("install", "uninstall"), nargs="?", default="install")
    parser.add_argument("--bundle", type=Path,
                        default=Path(os.environ.get(
                            "EGM_BUNDLE_DIR",
                            str(Path.home() / ".local/share/egm-android-arm64/bundle"))))
    parser.add_argument("--config", type=Path,
                        default=Path(os.environ.get(
                            "OPENCODE_CONFIG_DIR", str(Path.home() / ".config/opencode"))))
    parser.add_argument("--force", action="store_true",
                        help="allow reinstalling over an existing managed bundle")
    args = parser.parse_args()

    if args.action == "uninstall":
        return uninstall(args.bundle.expanduser().resolve(), args.config.expanduser().resolve())

    if args.bundle.exists() and not args.force and load_manifest(args.bundle.parent):
        print("error: already installed; run uninstall first or pass --force", file=sys.stderr)
        return 2
    return install(args.bundle.expanduser().resolve(), args.config.expanduser().resolve(), args.force)


if __name__ == "__main__":
    raise SystemExit(main())
