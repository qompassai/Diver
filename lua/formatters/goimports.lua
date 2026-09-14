-- #################################################################
-- ~/.config/nvim/lua/formatters/goimports.lua
-- Qompass AI Diver Goimports Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
-- Requires your native formatters/init.lua (FormatterSpec/FormatterContext).
-- No formatter plugin. The runner owns deadlines, cancellation, byte limits,
-- stale-result checks and atomic buffer updates. Neither tool writes source files.
-- Use goimports followed by gofumpt, with one formatting trigger for Go.
-- External Go environment (PATH, GOROOT, GOPATH, GOWORK, GOFLAGS, etc.) is
-- intentionally inherited so project/toolchain resolution stays consistent.
-- CLI reference: golang.org/x/tools v0.50.0, cmd/goimports (gc build).
-- No positional file or '-' argument: zero operands selects stdin.
-- -srcdir is filename metadata only, including for a new unsaved .go file.
-- -local='' disables special local-prefix grouping; set a comma-separated
-- prefix list below if desired. No automatic guesses from go.mod.
-- -h/-help are deliberately omitted: Go's flag package treats their presence
-- as a help request, even with '=false'.
-- No YAML/TOML config. GOPATH/src/.goimportsignore remains an upstream input.
-- TabWidth=8, TabIndent=true, Comments=true and Fragment=true are fixed by
-- the upstream CLI and cannot be changed with flags.
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

---@param context FormatterContext
---@return string[]
local function arguments(context)
  local filename = context.filename
  if filename == '' then
    filename = vim.fs.joinpath(context.root, 'stdin.go')
  end
  return {
    '-l=false', -- Do not list changed filenames.
    '-w=false', -- Never overwrite the source file.
    '-d=false', -- Return source, not a diff.
    '-e=true', -- Report all parse errors on stderr.
    '-v=false', -- Disable verbose import-resolution logging.
    '-format-only=false', -- Add missing imports and remove unused imports.
    '-local=', -- No special local import prefixes.
    '-srcdir=' .. filename,
    '-cpuprofile=', -- Disabled: no profiling files.
    '-memprofile=',
    '-memrate=0',
    '-trace=', -- gc-build trace flag; disabled.
  }
end

---@type FormatterSpec
return {
  cmd = 'goimports',
  args = arguments,
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