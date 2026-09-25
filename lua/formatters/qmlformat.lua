-- #################################################################
-- ~/.config/nvim/lua/formatters/qmlformat.lua
-- Qompass AI Diver qmlformat Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://doc.qt.io/qt-6.8/qtqml-tooling-qmlformat.html
---
--- ELI5: qmlformat is Qt's tidy-up robot for QML files. It cannot read
--- from stdin -- it needs a real file -- so the runner hands it a
--- private copy of the buffer and reads the answer back from stdout.
--- `-w 4` asks for four-space indentation (its own default, stated out
--- loud). The inplace flag is deliberately NOT used: the runner owns
--- the buffer, qmlformat only lends its eyes.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    return {
        '-w',
        '4',
        assert(context.tempfile),
    }
end

---@type FormatterSpec
return {
    cmd = 'qmlformat',
    args = build_args,
    mode = 'tempfile',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { '.qmlformat.ini', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'qml',
    decode = nil,
    pre_transform = nil,
}
