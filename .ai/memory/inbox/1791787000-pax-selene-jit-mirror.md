---
origin_lane: qompassai
content_label: sfw
---

# Selene jit std fix mirrored (2026-10-11)

Commit 192efea6 (FF 8ae87df5..192efea6): lua51.yml gains `jit: { property: read-only }`
between ipairs and load. The vendored lua51 std modeled LuaJIT's `bit` but not `jit`;
with undefined_variable=deny, health.lua's `jit ~= nil` probe errored. Gates at fix
time: selene on health.lua 0 errors/0 warnings/0 parse errors; tree-wide
'jit is not defined' findings 0. Live change was sha-verified into a worktree off
origin/main; main checkout untouched.
