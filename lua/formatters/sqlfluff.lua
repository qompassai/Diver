-- #################################################################
-- ~/.config/nvim/lua/formatters/sqlfluff.lua
-- Qompass AI Diver sqlfluff fix Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/sqlfluff/sqlfluff
---
--- ELI5: sqlfluff is a SQL linter that can also fix what it finds.
--- `fix` with `-` reads your SQL from stdin; `--stdin-filename`
--- points it at the buffer's file so it finds the right `.sqlfluff`
--- config; `--force` skips the "are you sure?" prompt and `--quiet`
--- keeps its chatter off stdout. Exit code 1 means some violations
--- could not be fixed -- the fixed SQL is still on stdout.
--- Marked manual, not automatic: it applies lint fixes, not just
--- whitespace, so run it on purpose.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    if context.filename ~= '' then
        return {
            'fix',
            '--force',
            '--quiet',
            '--stdin-filename',
            context.filename,
            '-',
        }
    end
    return { 'fix', '--force', '--quiet', '-' }
end

---@type FormatterSpec
return {
    cmd = 'sqlfluff',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { '.sqlfluff', 'pyproject.toml', 'tox.ini', 'setup.cfg', '.git' },
    exit_codes = { 0, 1 },
    allow_empty = false,
    automatic = false,
    extension = 'sql',
    decode = nil,
    pre_transform = nil,
}
