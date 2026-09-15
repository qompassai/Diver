-- #################################################################
-- ~/.config/nvim/lua/formatters/pint.lua
-- Qompass AI Diver Laravel Pint Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
-- Requires the native formatters/init.lua supplied earlier, no plugin.
-- CLI reference: Laravel Pint v1.24.0 (https://github.com/laravel/pint).
--
-- Composer project installation: composer require --dev laravel/pint
-- Expose its executable on PATH or set cmd to an absolute trusted executable.
-- Do not use a relative vendor/bin path: executable resolution precedes cwd.
--
-- Pint has no stdin mode. It only accepts file/directory path arguments, so
-- this spec runs in mode = 'tempfile' and the runner reads the tempfile back
-- after Pint has rewritten it in place.
--
-- Pint auto-discovers pint.json relative to its working directory when no
-- --config is given, so cwd is pinned to context.root, not the tempfile's own
-- (private, formatter-owned) directory.
--
-- Pint's default action (no subcommand) fixes the given path and exits 0 on
-- success. --test and --repair intentionally return nonzero on style errors
-- and are check-only modes, not appropriate for a buffer-formatting spec.
--
-- The runner owns the private file, cleanup, deadlines, output limits, undo,
-- cancellation and stale-result rejection. Nonzero exits preserve the buffer.

---@param context FormatterContext
---@return string
local function working_directory(context)
  return context.root
end

---@param context FormatterContext
---@return string[]
local function arguments(context)
  local tempfile = context.tempfile
  if not tempfile or tempfile == '' then
    error('pint requires a private tempfile from the native formatter runner')
  end

  local args = {}
  args[#args + 1] = '--'
  args[#args + 1] = tempfile
  return args
end

---@type FormatterSpec
return {
  cmd = 'pint',
  args = arguments,
  mode = 'tempfile',
  output = 'file',
  cwd = working_directory,
  root_markers = { 'pint.json', 'composer.json', '.git' },
  env = { NO_COLOR = '1' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
  extension = 'php',
}