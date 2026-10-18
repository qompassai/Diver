-- /qompassai/diver/lua/utils/ux/ui.lua
-- Qompass AI UX-UI Utils
---@module 'config.ui.ui'
local M = {}
local transparency = require('config.ui.transparency')
local virtual_text = require('config.ui.vt')
M.clear = virtual_text.clear
M.code_lens = virtual_text.code_lens
M.disable_transparency = transparency.disable
M.enable_transparency = transparency.enable
M.inline_hint = virtual_text.inline_hint
function M.setup(opts)
    opts = opts or {}

    if opts.len_hints then
        virtual_text.setup({
            len_hints = opts.len_hints,
        })
    end

    if opts.transparency then
        transparency.setup(opts.transparency)
    end
end
M.setup_len_hints = virtual_text.setup_len_hints
M.setup_transparency = transparency.setup
M.toggle_transparency = transparency.toggle
M.transparency = transparency
M.virtual_text = virtual_text
return M
