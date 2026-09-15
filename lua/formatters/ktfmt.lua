-- #################################################################
-- ~/.config/nvim/lua/formatters/ktfmt.lua
-- Qompass AI Diver Native Kotlin Formatter
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
local fs = vim.fs

local TOOLING = {
  java = 'java',
  jar = fs.joinpath(vim.fn.stdpath('data'), 'formatters', 'ktfmt', 'ktfmt-0.64-with-dependencies.jar'),
  adapter = fs.joinpath(vim.fn.stdpath('data'), 'formatters', 'ktfmt', 'KtfmtStdin.java'),
  max_input_bytes = 2 * 1024 * 1024,
  max_output_bytes = 4 * 1024 * 1024,
  initial_heap_mib = 32,
  maximum_heap_mib = 512, -- JVM heap cap, not a total-process memory limit.
  active_processors = 2,
}

local CONFIG = {
  max_width = 100,
  block_indent = 4,
  continuation_indent = 4,
  trailing_comma_strategy = 'COMPLETE', -- 'NONE' | 'ONLY_ADD' | 'COMPLETE'
  remove_unused_imports = false,
  preserve_lambda_breaks = true,
  debugging_print_ops = false, -- Must remain false: stdout is source only.
  enable_editorconfig = true,
}

---@param context FormatterContext
---@return string[]
local function arguments(context)
  if context.filetype ~= 'kotlin' then
    error('ktfmt requires the kotlin filetype (both .kt and .kts)')
  end
  local stat = vim.uv.fs_stat(TOOLING.jar)
  if not stat or stat.type ~= 'file' then
    error('Install the ktfmt 0.64 with-dependencies JAR at ' .. TOOLING.jar)
  end
  local adapter_stat = vim.uv.fs_stat(TOOLING.adapter)
  if not adapter_stat or adapter_stat.type ~= 'file' then
    error('Install the companion Java adapter at ' .. TOOLING.adapter)
  end
  if CONFIG.debugging_print_ops then
    error('ktfmt debugging output is incompatible with source-only stdout')
  end
  local filename = context.filename
  if filename == '' then
    filename = fs.joinpath(context.root, 'stdin.kt')
  end
  return {
    '-Xms' .. tostring(TOOLING.initial_heap_mib) .. 'm',
    '-Xmx' .. tostring(TOOLING.maximum_heap_mib) .. 'm',
    '-XX:ActiveProcessorCount=' .. tostring(TOOLING.active_processors),
    '-XX:+UseSerialGC',
    '-Dfile.encoding=UTF-8',
    '-Djava.awt.headless=true',
    '--class-path',
    TOOLING.jar,
    TOOLING.adapter,
    filename,
    tostring(CONFIG.max_width),
    tostring(CONFIG.block_indent),
    tostring(CONFIG.continuation_indent),
    CONFIG.trailing_comma_strategy,
    tostring(CONFIG.remove_unused_imports),
    tostring(CONFIG.preserve_lambda_breaks),
    tostring(CONFIG.enable_editorconfig),
    tostring(TOOLING.max_input_bytes),
    tostring(TOOLING.max_output_bytes),
    tostring(CONFIG.debugging_print_ops),
  }
end

---@param context FormatterContext
---@return string
local function working_directory(context)
  return context.root
end

---@type FormatterSpec
return {
  cmd = TOOLING.java,
  args = arguments,
  mode = 'stdin',
  output = 'stdout',
  cwd = working_directory,
  root_markers = {
    '.editorconfig',
    'settings.gradle.kts',
    'settings.gradle',
    'build.gradle.kts',
    'build.gradle',
    'gradle.properties',
    'pom.xml',
    '.git',
  },
  env = {
    NO_COLOR = '1',
    JAVA_TOOL_OPTIONS = '',
    JDK_JAVA_OPTIONS = '',
    _JAVA_OPTIONS = '',
  },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
  extension = 'kt',
}