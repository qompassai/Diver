-- #################################################################
-- ~/.config/nvim/lua/formatters/clang_format.lua
-- Qompass AI Diver Native Clang-Format Formatter
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
-- Requires your native formatters/init.lua, not a formatter plugin.
-- Tool: clang-format on PATH. On Arch, supplied by the clang package.
-- Match clang-format and clangd major versions for consistent style support.
-- Uses shared .clang-format/_clang-format, including parent inheritance.
-- No independent style overrides: clangd and this formatter read the same style.
-- LLVM fallback matches clangd's default when no style file exists.
-- If .clangd config overrides clangd's fallback, set fallback_style to match it.
--
-- Reviewed Diver lsp/clangd_ls.lua: no formatting-on-save hook in that file.
-- This adapter does not alter clangd capabilities or register another autocmd.
-- Keep one formatting trigger in the native runner; separately configured
-- LSP formatting/on-type formatting can still cause additional edits.
-- Keep clangd completion, diagnostics, code actions and header switching enabled.
-- Explicit invocation :Format clang_format does not request LSP fallback.
--
-- Entire buffer goes to stdin. --assume-filename is metadata, not a write target.
-- No -i, --files, positional files, cursor header, XML, dry run or dump config.
-- No range flags: this runner handles whole buffers. No include/qualifier
-- overrides: those belong in the shared style file, not in a second style.
-- .clang-format-ignore handling of file operands is not promised for stdin.
-- The runner owns cancellation, deadlines, output limits, undo and stale checks.
-- Clang-format is not a C/C++ syntax validator; clangd remains the diagnostic tool.
local CONFIG = {
  executable = 'clang-format',
  style = 'file',
  fallback_style = 'LLVM',
}

---@type table<string, string>
local EXTENSIONS = {
  c = 'c',
  cpp = 'cpp',
  cuda = 'cu',
  objc = 'm',
  objcpp = 'mm',
  proto = 'proto',
}

---@param context FormatterContext
---@return string[]
local function arguments(context)
  local extension = EXTENSIONS[context.filetype]
  if not extension then
    error('clang_format: unsupported filetype ' .. context.filetype)
  end
  local filename = context.filename
  if filename == '' then
    filename = vim.fs.joinpath(context.root, 'stdin.' .. extension)
  end
  return {
    '--style=' .. CONFIG.style,
    '--fallback-style=' .. CONFIG.fallback_style,
    '--assume-filename=' .. filename,
    '--fail-on-incomplete-format',
    '--Werror', -- Unknown/invalid style settings must not silently change style.
  }
end

---@param context FormatterContext
---@return string
local function working_directory(context)
  return context.root
end

---@type FormatterSpec
return {
  cmd = CONFIG.executable,
  args = arguments,
  mode = 'stdin',
  output = 'stdout',
  cwd = working_directory,
  root_markers = {
    '.clang-format',
    '_clang-format',
    '.clangd',
    'compile_commands.json',
    'compile_flags.txt',
    'CMakeLists.txt',
    '.git',
  },
  env = { NO_COLOR = '1' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
  extension = 'cpp', -- Inactive in stdin mode; language uses assume-filename.
}