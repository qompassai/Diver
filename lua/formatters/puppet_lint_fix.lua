-- #################################################################
-- ~/.config/nvim/lua/formatters/puppet_lint_fix.lua
-- Qompass AI Diver Puppet Lint Fix Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/puppetlabs/puppet-lint
---
--- puppet-lint checks Puppet manifests; `--fix` rewrites the given
--- file in place, correcting whatever it can. The runner hands it a
--- throwaway copy and reads the corrected copy back from disk. The
--- "FIXED:" notices go to stdout and are ignored; only the exit
--- code decides whether the rewritten file is kept.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    return { '--fix', context.tempfile }
end

---@type FormatterSpec
return {
    cmd = 'puppet-lint',
    args = build_args,
    mode = 'tempfile',
    output = 'file',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'pp',
}
