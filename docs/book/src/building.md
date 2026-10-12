# Building these docs

The API reference is generated, never handwritten:

1. Lua sources carry LuaCATS annotations (`---@param`, `---@class`,
   `---@field`, …) — the same annotations LuaLS checks on every file.
2. `docs/book/build-api.sh` runs
   [emmylua_doc_cli](https://github.com/CppCXY/emmylua-analyzer-rust)
   (a LuaCATS-native generator) over the repo with the repo's own
   `.luarc.json`, producing one markdown page per module and per type.
3. A deterministic post-pass tidies the generator's whitespace, the
   generated section of `src/SUMMARY.md` is spliced between its API
   markers, and mdBook renders the book to `docs/book/book/`.

From inside Neovim, `:DiverBook build` runs the script and
`:DiverBook open` rebuilds when sources are newer than the last
build, then opens the book.

<details>
<summary>Why not LDoc?</summary>

LDoc predates LuaCATS. On this codebase it aborts on standalone
`---@class` blocks, silently emits nothing for richly annotated
modules, and its markdown mode writes nothing at all — measured in
an on-machine pilot (2026-10-11, against `lua/dev/scip`).
emmylua_doc_cli passed the same pilot with every function and every
class documented, at full type fidelity.

</details>

<details>
<summary>What is committed, what is generated</summary>

Committed: `book.toml`, `build-api.sh`, the handwritten chapters in
`src/`, and the marked `SUMMARY.md` skeleton. Generated and
gitignored: `src/api/` and the rendered `book/`. The build also
reports any module with zero documented entries — that list is the
annotation-coverage audit; a module appearing there needs
annotations, not a docs workaround.

</details>
