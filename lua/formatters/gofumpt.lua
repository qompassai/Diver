-- #################################################################
-- ~/.config/nvim/lua/formatters/gofumpt.lua
-- Qompass AI Diver Gofumpt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
-- Requires your native formatters/init.lua (FormatterSpec/FormatterContext).
-- No formatter plugin. The runner owns deadlines, cancellation, byte limits,
-- stale-result checks and atomic buffer updates. Neither tool writes source files.
-- Use goimports followed by gofumpt, with one formatting trigger for Go.
-- External Go environment (PATH, GOROOT, GOPATH, GOWORK, GOFLAGS, etc.) is
-- intentionally inherited so project/toolchain resolution stays consistent.
-- CLI reference: mvdan.cc/gofumpt v0.12.0.
-- Zero operands selects stdin (do not append a filename or '-').
-- Empty -lang/-modpath explicitly select upstream go.mod inference. Running
-- from the source directory preserves nested-module discovery for stdin.
-- Set -lang=go1.X and -modpath=example.org/module here to override inference.
-- Outside a module the tool uses its own fallback language/grouping rules.
-- -extra=false disables optional extra rules. Standard simplification is
-- ALWAYS enabled upstream, regardless of the legacy -s flag.
-- -r='' disables the removed rewrite feature; a nonempty value is an error.
-- -h/-help are omitted because they request help, even with '=false'.
-- No style config file. Tabs/tab width 8 and standard formatting are fixed
-- upstream, not derived from Neovim shiftwidth/expandtab.
-- Explicit stdin is formatted even when the source has a generated-code header.
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
  root_markers = { 'go.mod', 'go.work', '.git' },
  env = { NO_COLOR = '1', GOTOOLCHAIN = 'local' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
  extension = 'go',
}