# Introduction

Diver is a Neovim configuration built to a simple north star: need no
plugins unless you want them, keep everything Tiger Style and
deterministic, and let the config itself cue in the information that
multi-language workflows — human and AI-agent alike — need, so the
config can be handed to someone else and adapted easily.

This book is the config's documentation. The narrative chapters are
handwritten. The API reference is not: it is generated from the
LuaCATS annotations in the Lua sources, which stay the single source
of truth. If a page here disagrees with the code, the code is right
and the page is stale — rebuild (see *Building these docs*).

<details>
<summary>How the book is organized</summary>

- **Guide** — handwritten chapters: architecture, subsystem tours,
  and the docs pipeline itself.
- **API Reference (generated)** — one page per Lua module and per
  LuaCATS type, produced by `docs/book/build-api.sh`. Entries carry
  the full annotated signatures: parameter and return types, callback
  types, and class fields.

</details>
