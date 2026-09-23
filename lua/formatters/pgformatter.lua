-- #################################################################
-- ~/.config/nvim/lua/formatters/pg_format.lua
-- Native pgFormatter Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/darold/pgformatter/releases/tag/v5.11
---
--- Tiger Style for SQL formatting profile (tiger style formatting rules:
--- 4-space indentation, 100-column review target, deterministic output).
--- pgFormatter's own default indent is already 4 spaces; it is pinned
--- explicitly so the profile survives upstream default changes.
--- `--no-rcfile` keeps the result independent of stray .pg_format files:
--- the flags below ARE the pinned profile, exactly as the SQL todo item
--- requires ("prefer for PostgreSQL-specific repositories").
--- Upstream case defaults are kept deliberately: keywords uppercase,
--- type names lowercase, identifiers and functions unchanged.

local PG_FORMAT_WIDTH = 100
local PG_FORMAT_INDENT = 4

---@class PgFormatConfig
---@field width integer Wrap queries at this column count (tiger-style: 100).
---@field indent integer Indent width in spaces (tiger-style: 4).
---@field no_rcfile boolean Ignore .pg_format rc files for deterministic output.

---@type PgFormatConfig
local CONFIG = {
  width = PG_FORMAT_WIDTH,
  indent = PG_FORMAT_INDENT,
  no_rcfile = true,
}

assert(
  CONFIG.width > 0 and CONFIG.width <= 1000,
  'pg_format: width must be within 1..1000 columns'
)
assert(
  CONFIG.indent > 0 and CONFIG.indent <= 16,
  'pg_format: indent must be within 1..16 spaces'
)

---@param context FormatterContext
---@return string[]
local function build_args(context)
  if context.filetype ~= 'sql' then
    error('pg_format requires the sql filetype')
  end

  local args = {
    '--spaces',
    tostring(CONFIG.indent),
    '--wrap-limit',
    tostring(CONFIG.width),
  }

  if CONFIG.no_rcfile then
    args[#args + 1] = '--no-rcfile'
  end

  -- `-` selects stdin, matching upstream usage examples.
  args[#args + 1] = '-'

  return args
end

---@type FormatterSpec
return {
  cmd = 'pg_format',
  args = build_args,
  mode = 'stdin',
  output = 'stdout',
  root_markers = { '.git' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
}