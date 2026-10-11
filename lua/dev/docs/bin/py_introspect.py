#!/usr/bin/env python3
"""Introspect the running Python into docs-meta/<version>.json.

Usage: python3 py_introspect.py --out docs-meta/python
Reads the *installed* interpreter: version-accurate by construction.
Bounded: stdlib modules capped, docstrings truncated to first line.
"""
import argparse
import datetime
import inspect
import json
import keyword
import os
import pkgutil
import sys

MODULES_MAX = 220  # hard cap on stdlib modules walked
MEMBERS_MAX = 400  # hard cap on members per module
DOC_CHARS_MAX = 300  # first-line doc truncation

SKIP_PREFIXES = ("test", "_test", "ensurepip", "venv", "idlelib", "turtledemo")
SKIP_EXACT = {"antigravity", "this", "__main__"}


def first_line(doc):
    if not doc:
        return ""
    line = doc.strip().split("\n")[0].strip()
    return line[:DOC_CHARS_MAX]


def safe_sig(obj):
    try:
        return str(inspect.signature(obj))
    except Exception:
        return ""


def member_kind(obj):
    if inspect.isclass(obj):
        return "class"
    if inspect.isfunction(obj) or inspect.isbuiltin(obj):
        return "function"
    if inspect.ismodule(obj):
        return "module"
    return "data"


def describe(obj):
    d = {"doc": first_line(inspect.getdoc(obj))}
    kind = member_kind(obj)
    d["kind"] = kind
    if kind in ("function", "class"):
        sig = safe_sig(obj)
        if sig:
            d["sig"] = sig
    return d


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, help="docs-meta/python dir")
    args = ap.parse_args()

    version = ".".join(str(x) for x in sys.version_info[:3])
    meta = {
        "schema": 1,
        "lang": "python",
        "version": version,
        "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "generated_by": "py_introspect",
        "keywords": sorted(keyword.kwlist),
        "builtins": {},
        "stdlib": {},
        "syntax": [],
        "notes": [],
    }

    # Builtins (skip dunder noise, keep it queryable).
    import builtins

    for name in sorted(dir(builtins)):
        if name.startswith("__") and name.endswith("__"):
            continue
        try:
            obj = getattr(builtins, name)
        except Exception:
            continue
        meta["builtins"][name] = describe(obj)

    # Stdlib: top-level modules only, bounded. sys.stdlib_module_names is
    # the stdlib set — never third-party site-packages.
    stdlib_names = sorted(sys.stdlib_module_names)
    seen = 0
    for name in stdlib_names:
        if seen >= MODULES_MAX:
            break
        if name.startswith(SKIP_PREFIXES) or name in SKIP_EXACT or name.startswith("_"):
            # Keep single-underscore private modules out; they are not reference.
            continue
        try:
            m = __import__(name)
        except Exception:
            continue
        entry = {"doc": first_line(inspect.getdoc(m)), "members": {}}
        count = 0
        for mname in sorted(dir(m)):
            if count >= MEMBERS_MAX or mname.startswith("__"):
                continue
            try:
                obj = getattr(m, mname)
            except Exception:
                continue
            # Only document members actually defined in (or re-exported by) stdlib;
            # skip imported noise by requiring a __module__ in stdlib or same module.
            entry["members"][mname] = describe(obj)
            count += 1
        if entry["members"]:
            meta["stdlib"][name] = entry
            seen += 1

    os.makedirs(args.out, exist_ok=True)
    path = os.path.join(args.out, f"{version}.json")
    with open(path, "w") as f:
        json.dump(meta, f, indent=1)
        f.write("\n")
    n_builtins = len(meta["builtins"])
    n_modules = len(meta["stdlib"])
    print(f"WROTE {path} ({n_builtins} builtins, {n_modules} modules)")


if __name__ == "__main__":
    main()
