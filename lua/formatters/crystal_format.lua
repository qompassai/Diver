-- #################################################################
-- ~/.config/nvim/lua/formatters/crystal_format.lua
-- Native crystal tool format Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---
--- Tiger Style note for Crystal: `crystal tool format -` reads stdin and
--- emits the formatted source on stdout (the positional `-` selects stdin).
--- `--no-color` keeps diagnostics plain for the runner to capture. The
--- formatter is opinionated; no width or indentation flags exist, so the
--- canonical Crystal style is kept as-is.

---@param context FormatterContext
---@return string[]
local function build_args(context)
  if context.filetype ~= 'crystal' then
    error('crystal_format requires the crystal filetype')
  end

  return { 'tool', 'format', '--no-color', '-' }
end

---@type FormatterSpec
return {
  cmd = 'crystal',
  args = build_args,
  mode = 'stdin',
  output = 'stdout',
  root_markers = { 'shard.yml', '.git' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
}