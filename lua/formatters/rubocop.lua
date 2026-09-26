-- #################################################################
-- ~/.config/nvim/lua/formatters/rubocop.lua
-- Qompass AI Diver RuboCop Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/rubocop/rubocop
---
--- ELI5: RuboCop is Ruby's code police and tidy-up robot in one.
--- `--stdin <name>` feeds it your buffer through stdin (the name tells
--- it which file's rules and exclusions apply), `--autocorrect`
--- applies only the fixes it knows are safe, and
--- `--format quiet --stderr` keeps its chatter on stderr so stdout
--- holds just the corrected code. Exit code 1 simply means "offenses
--- were found" -- the corrected source is still on stdout.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local name = context.filename
    if name == '' then
        name = 'buffer.rb'
    end
    return {
        '--autocorrect',
        '--format',
        'quiet',
        '--stderr',
        '--stdin',
        name,
    }
end

---@type FormatterSpec
return {
    cmd = 'rubocop',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { '.rubocop.yml', '.rubocop.yaml', 'Gemfile', '.git' },
    exit_codes = { 0, 1 },
    allow_empty = false,
    automatic = true,
    extension = 'rb',
    decode = nil,
    pre_transform = nil,
}
