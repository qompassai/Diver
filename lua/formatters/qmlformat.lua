-- ~/.config/nvim/lua/formatters/qmlformat.lua
-- Qompass AI Diver qmlformat Native Formatter Spec
---@module 'formatters.qmlformat'
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
    allow_empty = false,
    args = build_args,
    automatic = true,
    cmd = 'qmlformat',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0 },
    extension = 'qml',
    mode = 'tempfile',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { '.qmlformat.ini', '.git' },
}
