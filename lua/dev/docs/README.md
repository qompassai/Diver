# docs-meta: versioned language reference for AI agents

Local, versioned, machine-readable language documentation. Agents query
it instead of curling docs and parsing HTML.

## Why not scrape docs?

Scraping drifts: HTML changes, versions blur, tokens burn. docs-meta
**introspects the installed toolchain** — `pydoc` for Python, the Lua
interpreter for Lua — so metadata is version-accurate by construction.
New toolchain version → new JSON file. Zero parsing, zero drift.

## Layout

```
~/.local/share/diver/docs-meta/   # XDG_DATA_HOME-aware; NOT in git
├── manifest.json                 # {"python": ["3.14.8", ...], "lua": ["5.5"]}
├── python/3.14.8.json
└── lua/5.5.json
```

## Query

```bash
diver-docs <lang> [version] <query>   # version defaults to newest
diver-docs python asyncio.run
diver-docs lua 5.4 string.find
```

In Neovim: `:DiverDocs python asyncio.run` (float with hits),
`:DiverDocsUpdate` regenerates metadata for installed toolchains.

## Schema

See `SCHEMA.md`. Per file: keywords, builtins (sig + one-line doc),
stdlib modules (members with sigs), syntax constructs, version notes.
Docstrings truncated to first line — full text stays in the toolchain.

## Adding a language

1. Write `bin/<lang>_introspect` that dumps the schema JSON by
   introspecting the installed toolchain (never by scraping).
2. Add it to `M.update()` in `init.lua`.
3. Run `:DiverDocsUpdate`.

## Version updates

When Owner installs a new toolchain (e.g. Python 3.15), run
`:DiverDocsUpdate`. The introspector writes `python/3.15.x.json`,
the manifest gains the version, and queries default to it. Old
versions stay cached for pinning (`diver-docs python 3.14.8 ...`).
