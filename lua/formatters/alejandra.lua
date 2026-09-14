-- #################################################################
-- ~/.config/nvim/lua/formatters/alejandra.lua
-- Native Alejandra Nix Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/kamadorueda/alejandra/releases/tag/4.0.0
--
-- Requires Alejandra 4.0.0 and the native formatters/init.lua runner.
-- Install the executable separately; this module never installs tools.
--
-- After require('formatters').setup(), select only Alejandra for Nix:
--   require('formatters').formatters_by_ft.nix = { 'alejandra' }
--
-- :Format uses the external formatter when available, without an LSP pass.
-- :Format alejandra explicitly requires Alejandra and never falls back to LSP.
-- Keep nil_ls/nixd_ls and Statix/Deadnix diagnostics enabled. This module does
-- not publish duplicate diagnostics, disable servers, run code actions, or
-- call statix fix / deadnix --edit. Do not also format Nix from a separate LSP
-- save autocmd: use this runner as the sole automatic formatting trigger.
--
-- Buffer text enters stdin; formatted source leaves stdout. No original file
-- path is passed as an input/write target. The runner stages the result and
-- owns undo, cancellation, output limits, timeout and stale-result rejection.
-- Syntax/CLI failures return exit 1 and leave the buffer unchanged.
--
-- Configuration: Alejandra loads alejandra.toml from its working directory.
-- Prefer the nearest such config within the detected Nix project boundary;
-- otherwise run from that project root and use Alejandra's default style.
-- --check is disabled: a formatter needs source text, not lint-check output.
-- --exclude is unused for a single stdin buffer. Quiet is used once so error
-- messages remain on stderr. One thread overrides ALEJANDRA_THREADS.
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
    if parent == directory then
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