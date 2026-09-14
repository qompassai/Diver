-- #################################################################
-- ~/.config/nvim/lua/formatters/phpcsfixer.lua
-- Qompass AI Diver PHP-CS-Fixer Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
-- Requires the native formatters/init.lua supplied earlier, no plugin.
-- CLI reference: PHP-CS-Fixer v3.95.25.
-- Executable: php-cs-fixer on PATH (install separately).
-- Composer project installation: composer require --dev friendsofphp/php-cs-fixer
-- Expose its executable on PATH or set cmd to an absolute trusted executable.
-- Do not use a relative vendor/bin path: executable resolution precedes cwd.
-- LuaLS 3.19.1: no diagnostics with the runner's FormatterSpec declarations.
-- Runtime tested with PHP-CS-Fixer 3.95.25 / PHP 8.3 / Neovim 0.12.5.
-- Target is Neovim 0.13+; a 0.13 executable was unavailable for testing.
-- Invalid PHP can be skipped with exit zero; this adapter does not translate
-- JSON report errors into diagnostics. Keep a separate PHP syntax linter.
-- After setup: require('formatters').formatters_by_ft.php = { 'phpcsfixer' }
-- Explicit invocation: :Format phpcsfixer
--
-- Project configs are executable PHP: use only trusted projects/configs.
-- The nearest .php-cs-fixer.php or .php-cs-fixer.dist.php within the runner's
-- project root supplies rules/custom fixers. Without one, use @PSR12.
-- --path-mode=override intentionally bypasses the config Finder: format the
-- selected buffer's private copy, even if Finder excludes the original file.
-- A private copy changes filename/location-sensitive custom fixer behavior.
-- This is a buffer formatter, not a project-wide Finder/check command.
--
-- The runner owns the private file, cleanup, deadlines, output limits, undo,
-- cancellation and stale-result rejection. Nonzero exits preserve the buffer.
-- JSON stdout is a report; the formatted source is read from the private file.
-- No --dry-run, --diff or --stop-on-violation: these are presence-only flags.
-- No --cache-file: caching is explicitly disabled. No --rules when a project
-- config exists, so its rules are preserved. Risky rules are always forbidden.
-- Use one formatting-on-save trigger; keep PHP LSP diagnostics enabled.
local fs = vim.fs

---@param context FormatterContext
---@return string
local function working_directory(context)
  return context.root
end

---@param context FormatterContext
---@return string?
local function project_config(context)
  local directory = context.root
  if context.filename ~= '' then
    directory = fs.dirname(context.filename) or context.root
  end
  while directory do
    for _, name in ipairs({ '.php-cs-fixer.php', '.php-cs-fixer.dist.php' }) do
      local path = fs.joinpath(directory, name)
      local stat = vim.uv.fs_stat(path)
      if stat and stat.type == 'file' then
        return path
      end
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
  return nil
end

---@param context FormatterContext
---@return string[]
local function arguments(context)
  local tempfile = context.tempfile
  if not tempfile or tempfile == '' then
    error('phpcsfixer requires a private tempfile from the native formatter runner')
  end
  local args = {
    'fix',
    '--allow-risky=no',
    '--allow-unsupported-php-version=no',
    '--using-cache=no',
    '--path-mode=override',
    '--format=json',
    '--show-progress=none',
    '--sequential',
    '--no-ansi',
    '--no-interaction',
  }
  local config = project_config(context)
  if config then
    args[#args + 1] = '--config=' .. config
  else
    args[#args + 1] = '--rules=@PSR12'
  end
  args[#args + 1] = '--'
  args[#args + 1] = tempfile
  return args
end

---@type FormatterSpec
return {
  cmd = 'php-cs-fixer',
  args = arguments,
  mode = 'tempfile',
  output = 'file',
  cwd = working_directory,
  root_markers = { '.php-cs-fixer.php', '.php-cs-fixer.dist.php', 'composer.json', '.git' },
  env = { NO_COLOR = '1', PHP_CS_FIXER_FUTURE_MODE = '0', PHP_CS_FIXER_IGNORE_ENV = '0' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
  extension = 'php',
}