-- #################################################################
-- ~/.config/nvim/lua/formatters/gleam_format.lua
-- Native gleam format Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---
--- Tiger Style note for Gleam: `gleam format --stdin` reads stdin and
--- emits the formatted source on stdout. The formatter is deliberately
--- non-configurable (2-space indentation is canonical), so no Tiger Style
--- width or indent flags exist; none are invented here.

---@param context FormatterContext
---@return string[]
local function build_args(context)
  if context.filetype ~= 'gleam' then
    error('gleam_format requires the gleam filetype')
  end

  return { 'format', '--stdin' }
end

---@type FormatterSpec
return {
  cmd = 'gleam',
  args = build_args,
  mode = 'stdin',
  output = 'stdout',
  root_markers = { 'gleam.toml', '.git' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
}