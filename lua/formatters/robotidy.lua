-- #################################################################
-- ~/.config/nvim/lua/formatters/robotidy.lua
-- Qompass AI Diver Robotidy Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/marketsquare/robotframework-tidy
---
--- ELI5: Robotidy tidies up Robot Framework test files. Giving it `-`
--- as the file name tells it to read your code from stdin and print
--- the tidied code to stdout, instead of rewriting files in place.
--- (This is the spiritual descendant of Robot Framework's old
--- `robot.tidy` tool.)

---@type FormatterSpec
return {
    cmd = 'robotidy',
    args = { '-' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { 'pyproject.toml', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'robot',
    decode = nil,
    pre_transform = nil,
}
