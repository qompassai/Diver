-- ~/.config/nvim/lua/formatters/puppet_lint_fix.lua
-- Qompass AI Diver Puppet Lint Fix Native Formatter Spec
---@module 'formatters.puppet_lint_fix'
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
    allow_empty = false,
    args = build_args,
    automatic = true,
    cmd = 'puppet-lint',
    exit_codes = { 0 },
    extension = 'pp',
    mode = 'tempfile',
    output = 'file',
}
