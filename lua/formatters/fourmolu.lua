-- #################################################################
-- ~/.config/nvim/lua/formatters/fourmolu.lua
-- Native Fourmolu Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/fourmolu/fourmolu
---
--- Fourmolu tidies Haskell code. `--mode stdout` flips it into pipe
--- mode: it reads the code from stdin and prints the pretty version
--- to stdout instead of rewriting files on disk. `--stdin-input-file`
--- lends the piped code a file name, so Fourmolu can find the
--- project's `fourmolu.yaml` and infer the module the way it would
--- for a file on disk. Unnamed buffers borrow `<root>/buffer.hs`.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local input_file = context.filename
    if input_file == '' then
        input_file = vim.fs.joinpath(context.root, 'buffer.hs')
    end
    return { '--mode', 'stdout', '--stdin-input-file', input_file }
end

---@type FormatterSpec
return {
    cmd = 'fourmolu',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    root_markers = { 'fourmolu.yaml', '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'hs',
}
