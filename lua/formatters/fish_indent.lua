-- #################################################################
-- ~/.config/nvim/lua/formatters/fish_indent.lua
-- Native fish_indent Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---
--- Tiger Style note for fish: `fish_indent` is a plain stdin/stdout filter
--- with no in-place flag and no indentation or width configuration. It is
--- opinionated, so the canonical fish style is kept as-is; no Tiger Style
--- flags are invented for it.

---@param context FormatterContext
---@return string[]
local function build_args(context)
  if context.filetype ~= 'fish' then
    error('fish_indent requires the fish filetype')
  end

  return {}
end

---@type FormatterSpec
return {
  cmd = 'fish_indent',
  args = build_args,
  mode = 'stdin',
  output = 'stdout',
  root_markers = { '.git' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
}