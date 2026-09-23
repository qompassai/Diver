-- #################################################################
-- ~/.config/nvim/lua/formatters/rescript_format.lua
-- Native rescript format Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/rescript-lang/rescript/blob/HEAD/CHANGELOG.md
---
--- ReScript 12 (Rust CLI) spelling: `rescript format --stdin <extension>`.
--- The legacy pre-12 CLI used the single-dash `-stdin <extension>`; that
--- spelling is not supported here. The extension is derived from the
--- buffer's filename so interface files (.resi) keep their syntax.

---@param context FormatterContext
---@return string[]
local function build_args(context)
  if context.filetype ~= 'rescript' then
    error('rescript_format requires the rescript filetype')
  end

  local extension = context.filename:match('%.res[ci]?$') or '.res'

  return { 'format', '--stdin', extension }
end

---@type FormatterSpec
return {
  cmd = 'rescript',
  args = build_args,
  mode = 'stdin',
  output = 'stdout',
  root_markers = { 'rescript.json', 'bsconfig.json', '.git' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
}