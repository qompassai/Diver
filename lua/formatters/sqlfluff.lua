-- ~/.config/nvim/lua/formatters/sqlfluff.lua
-- Qompass AI Diver sqlfluff fix Native Formatter Spec
---@module 'formatters.sqlfluff'
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
    allow_empty = false,
    args = build_args,
    automatic = false,
    cmd = 'sqlfluff',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0, 1 },
    extension = 'sql',
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { '.sqlfluff', 'pyproject.toml', 'tox.ini', 'setup.cfg', '.git' },
}
