-- #################################################################
-- ~/.config/nvim/lua/formatters/zig_fmt.lua
-- Native zig fmt Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---
--- Tiger Style note for Zig: `zig fmt --stdin` reads stdin and writes the
--- formatted source to stdout. The built-in formatter is opinionated
--- (4-space layout, ~100 columns per Tiger Style Zig); no width or
--- indentation flags exist, so none are passed.

---@param context FormatterContext
---@return string[]
local function build_args(context)
  if context.filetype ~= 'zig' then
    error('zig_fmt requires the zig filetype')
  end

  return { 'fmt', '--stdin' }
end

---@type FormatterSpec
return {
  cmd = 'zig',
  args = build_args,
  mode = 'stdin',
  output = 'stdout',
  root_markers = { 'build.zig', 'build.zig.zon', '.git' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
}