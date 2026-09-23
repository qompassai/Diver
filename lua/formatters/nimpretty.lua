-- #################################################################
-- ~/.config/nvim/lua/formatters/nimpretty.lua
-- Native nimpretty Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://manpages.debian.org/testing/nim/nimpretty.1.en.html
---
--- Tiger Style profile for Nim (4-space indentation, 100-column review
--- target). `nimpretty --stdin` reads stdin and writes the formatted
--- source to stdout. `--indent:4` and `--maxLineLen:100` pin the profile
--- explicitly; nimpretty's own defaults are narrower.

local NIMPRETTY_WIDTH = 100
local NIMPRETTY_INDENT = 4

---@param context FormatterContext
---@return string[]
local function build_args(context)
  if context.filetype ~= 'nim' then
    error('nimpretty requires the nim filetype')
  end

  return {
    '--stdin',
    '--indent:' .. tostring(NIMPRETTY_INDENT),
    '--maxLineLen:' .. tostring(NIMPRETTY_WIDTH),
  }
end

---@type FormatterSpec
return {
  cmd = 'nimpretty',
  args = build_args,
  mode = 'stdin',
  output = 'stdout',
  root_markers = { '.git' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
}