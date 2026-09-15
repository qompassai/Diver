-- #################################################################
-- ~/.config/nvim/lua/formatters/gofumpt.lua
-- Qompass AI Diver Gofumpt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@param context FormatterContext
---@return string
local function working_directory(context)
  if context.filename ~= '' then
    local directory = vim.fs.dirname(context.filename)
    if directory then
      return directory
    end
  end
  return context.root
end

---@type FormatterSpec
return {
  cmd = 'gofumpt',
  args = {
    '-l=false',
    '-w=false',
    '-d=false',
    '-e=true',
    '-lang=',
    '-modpath=',
    '-extra=false',
    '-version=false',
    '-cpuprofile=',
    '-r=', -- Compatibility flag only; no rewrite.
    '-s=false', -- Compatibility flag only; suppress deprecation warning.
  },
  mode = 'stdin',
  output = 'stdout',
  cwd = working_directory,
  root_markers = {
    'go.mod',
    'go.work',
    '.git',
  },
  env = {
    NO_COLOR = '1',
    GOTOOLCHAIN = 'local',
  },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
  extension = 'go',
}