# docs-meta schema v1

Versioned language-reference metadata for AI agents. Each file is
`docs-meta/<lang>/<version>.json`. Agents query locally instead of
curling docs.

## Top-level

```json
{
  "schema": 1,
  "lang": "python",
  "version": "3.14.7",
  "generated_at": "2026-10-05T08:00:00Z",
  "generated_by": "pydoc-introspect",
  "keywords": ["False", "None", "True", "and", "as", ...],
  "builtins": {
    "print": {
      "sig": "print(*args, sep=' ', end='\\n', file=None, flush=False)",
      "doc": "Print objects to the text stream file."
    }
  },
  "stdlib": {
    "os": {
      "doc": "OS routines for NT or Posix.",
      "members": {
        "getcwd": {"sig": "os.getcwd()", "doc": "Return a string..."},
        "path": {"kind": "module", "doc": "..."}
      }
    }
  },
  "syntax": [
    {"construct": "match statement",
     "example": "match x:\n  case 1:\n    ...",
     "since": "3.10"}
  ],
  "notes": ["3.14: t-strings added (PEP 750)"]
}
```

## Rules

- `version` is the exact toolchain version introspected, never "latest".
- `sig` is the real signature from introspection, not hand-written.
- `doc` is the first line (or first sentence) of the docstring — bounded,
  never the full text. Full text stays in the toolchain.
- `syntax` is hand-curated per language (small, stable); `notes` records
  version deltas the introspector cannot see (e.g. syntax additions).
- Missing data is omitted, never fabricated. If introspection fails for
  a module, it is absent from `stdlib`, not present with a guess.
- Files are regenerated, never hand-edited, except `syntax` and `notes`
  which live in `overlays/<lang>.json` and are merged at build time.

## Query contract

- `diver-docs <lang> [version] <query>`: version defaults to newest cached.
- Query matches against dotted paths (`os.path.join`), keywords, and
  construct names. Rank: exact > prefix > substring.
- Output is the JSON fragment, never prose — agents parse it.
- Exit 0 on hit, 1 on miss (with the available versions listed on stderr).

## Versioning

- `docs-meta/manifest.json`: `{ "<lang>": ["3.14.7", "3.13.15", ...] }`
  newest-first. The updater appends; the querier defaults to `[0]`.
- Introspectors run against the installed toolchain, so a new interpreter
  version yields a new file with zero scraping and zero drift.
