-- #################################################################
-- ~/.config/nvim/lua/formatters/v_fmt.lua
-- Native v fmt Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---
--- Tiger Style note for V: `v fmt -pipe` reads stdin, parses it and emits
--- the formatted source on stdout. The formatter is opinionated; no width
--- or indentation flags exist, so the canonical V style is kept as-is.

---@param context FormatterContext
---@return string[]
local function build_args(context)
  if context.filetype ~= 'v' then
    error('v_fmt requires the v filetype')
  end

  return { 'fmt', '-pipe' }
end

---@type FormatterSpec
return {
  cmd = 'v',
  args = build_args,
  mode = 'stdin',
  output = 'stdout',
  root_markers = { 'v.mod', '.git' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
}