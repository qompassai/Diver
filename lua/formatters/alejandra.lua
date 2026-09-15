-- #################################################################
-- ~/.config/nvim/lua/formatters/alejandra.lua
-- Native Alejandra Nix Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/kamadorueda/alejandra/releases/tag/4.0.0

local fs = vim.fs

---@param context FormatterContext
---@return string
local function working_directory(context)
  local start = context.filename ~= '' and fs.dirname(context.filename) or context.root
  local directory = start or context.root

  while directory do
    local config = fs.joinpath(directory, 'alejandra.toml')
    local stat = vim.uv.fs_stat(config)

    if stat and stat.type == 'file' then
      return directory
    end

    if directory == context.root then
      break
    end

    local parent = fs.dirname(directory)
    if parent == nil or parent == directory then
      break
    end

    directory = parent
  end

  return context.root
end

---@type FormatterSpec
return {
  cmd = 'alejandra',
  args = { '--quiet', '--threads', '1', '-' },
  mode = 'stdin',
  output = 'stdout',
  cwd = working_directory,
  root_markers = { 'flake.nix', 'default.nix', 'shell.nix', '.git' },
  env = { NO_COLOR = '1' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
}