-- ~/.config/nvim/lua/formatters/standardrb.lua
-- Qompass AI Diver StandardRB Native Formatter Spec
---@module 'formatters.standardrb'
---@source https://github.com/standardrb/standard
---
--- ELI5: StandardRB is Ruby's bikeshed-proof formatter -- zero config,
--- one true style. It wraps RuboCop, so like RuboCop,
--- `--stdin <name>` feeds it your buffer through stdin (the name tells
--- it which file's rules apply), `--fix` applies the automatic fixes,
--- and `--format quiet --stderr` keeps its chatter on stderr so stdout
--- holds just the fixed code. Exit code 1 simply means "offenses were
--- found" -- the fixed source is still on stdout.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local name = context.filename
    if name == '' then
        name = 'buffer.rb'
    end
    return {
        '--fix',
        '--format',
        'quiet',
        '--stderr',
        '--stdin',
        name,
    }
end

---@type FormatterSpec
return {
    allow_empty = false,
    args = build_args,
    automatic = true,
    cmd = 'standardrb',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0, 1 },
    extension = 'rb',
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { '.standard.yml', '.standard_todo.yml', 'Gemfile', '.git' },
}
