#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Yixuan Zhang
"""Check the source-only publication boundary; never inspect a user's Bottle."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
ignored = {".git", "build", "dist", ".cache", "__pycache__"}
forbidden = {".app", ".dll", ".exe", ".so", ".dylib", ".reg", ".dmg", ".log", ".zip"}
patterns = {
    "personal absolute home path": re.compile(r"/Users/[A-Za-z0-9._-]+/"),
    "GitHub token": re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,})\b"),
    "private key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "local device or Bottle identifier": re.compile(r"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b"),
}
errors = []
count = 0
for path in sorted(root.rglob("*")):
    relative = path.relative_to(root)
    if any(part in ignored for part in relative.parts):
        continue
    if path.is_symlink():
        errors.append(f"{relative}: symlinks are not allowed in the source publication")
        continue
    if path.suffix.lower() in forbidden or path.name.lower() in {"user.reg", "system.reg", "userdef.reg", "cxbottle.conf"}:
        errors.append(f"{relative}: runtime/private artifact type")
    if not path.is_file():
        continue
    if path.stat().st_size > 1024 * 1024:
        errors.append(f"{relative}: unexpected file larger than 1 MiB")
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        errors.append(f"{relative}: unexpected binary content")
        continue
    count += 1
    for label, pattern in patterns.items():
        if pattern.search(text):
            errors.append(f"{relative}: {label}")
    if path.suffix == ".patch":
        result = subprocess.run(["git", "apply", "--numstat", str(path)], capture_output=True, text=True)
        if result.returncode:
            errors.append(f"{relative}: malformed unified patch")
for expected in ["LICENSE", "LICENSES/LGPL-2.1-or-later.txt", "THIRD_PARTY_NOTICES.md", "README.md"]:
    if not (root / expected).is_file():
        errors.append(f"missing {expected}")
if errors:
    print("Publication checks failed:\n" + "\n".join(errors), file=sys.stderr)
    raise SystemExit(1)
print(f"Publication checks passed: {count} text files; source-only boundary and patch syntax verified.")
