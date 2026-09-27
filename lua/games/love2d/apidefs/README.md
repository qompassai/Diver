# LÖVE2D API Definitions

LuaCATS (`---@meta`) type stubs for the `love` global, consumed by
lua-language-server for completions and diagnostics in LÖVE2D projects.
These files never execute at runtime and are never `require`d; LuaLS reads
`---@meta` files as workspace-wide declarations.

## Source

- Spec: [love2d-community/love-api](https://github.com/love2d-community/love-api),
  commit `447486c14b7af6ffb610c47d9b800703b4e628f4` (structured API reports
  LÖVE **11.5** "Mysterious Mysteries").
- Generated 2026-09-27 by `/tmp/gen_apidefs.lua` (one-shot generator, not
  part of the repo):
  `lua gen_apidefs.lua /tmp/love-api lua/games/love2d/apidefs/love.lua`
- Do NOT hand-edit `love.lua`; re-run the generator against a pinned
  love-api checkout instead.

## Coverage (structured spec, 11.5)

- 19 modules (all of them, incl. graphics, audio, timer, keyboard, mouse,
  filesystem)
- 311 module functions
- 606 type methods
- 58 enums (as `---@alias` string-literal unions, e.g.
  `LoveGraphicsBlendMode`)
- 36 callbacks (`love.load`, `love.draw`, …)
- 4 root functions (`love.getVersion`, …)

## Honest gaps

- **Descriptions are first-line summaries.** Long prose from the spec is
  truncated to keep lines ≤ 120 columns; the full text lives upstream.
  Truncation can cut a multibyte character, so the generator replaces any
  resulting invalid UTF-8 sequence with `?` (one upstream description had
  a truncated `Ö`).
- **Unknown types become `any`.** When the spec names a type the generator
  cannot map to a module type, enum, or primitive, the parameter is typed
  `any` and the original spec type name is kept in the `---` note above it.
- **Only the max-arity variant is fully annotated.** Overloads with fewer
  arguments appear as `---@overload fun(...)` signature lines.
- **No value semantics.** Stub bodies are empty (signatures carry the real
  parameter names); the file describes shapes, not behavior. It cannot tell
  you what a function *does* beyond its signature and summary.
- **Pinned to 11.5.** Newer LÖVE versions (12.x nightlies) are not covered;
  regenerate from a newer love-api commit when the pinned runtime moves.

## Linting

Bare globals are by design here (the `love = {}` root and
`love.<module> = {}` assignments mirror the `lua/types/**` convention), so
the file carries its own `-- luacheck: ignore 111 112 113 212` pragma at
the top. The pragma is emitted by the generator and scoped to this file
only — no shared `.luacheckrc` change needed.

## Verification

2026-09-27: a scratch project with
`workspace.library = ["<repo>/lua/games/love2d/apidefs"]` under stock
LuaLS check mode reported **no** diagnostic for `love.graphics.print(...)`,
correct `undefined-field` for `love.graphics.no_such_function_xyz()`, and
still flagged a genuinely undefined global — i.e. the `love` global,
module tables, and field checking all work.
