-- /qompassai/Diver/lua/config/lang/yara.lua
-- Qompass AI Diver YARA Lang Config
---@module 'config.lang.yara'
-- Tooling (verified 2026-10-10): the language server is YARA-X's
-- official yr-ls (lsp/yara_ls.lua, enabled centrally); it provides
-- diagnostics and formatting. The linters catalog compile-checks
-- the yara filetype with yarac. No formatter is catalogued for
-- yara, no treesitter parser is installed, and no credible
-- language-specific MCP server or package-publish flow exists for
-- YARA rules (rules ship as files in git repos), so none is
-- declared here.
local M = {}
local api = vim.api
local fn = vim.fn
local group = api.nvim_create_augroup('Yara', {
    clear = true,
})
local header = require('research.docs')
local modernize = require('config.lang.modernize')

local function buf_is_empty()
    return api.nvim_buf_get_lines(0, 0, 1, false)[1] == ''
end

api.nvim_create_autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.yar',
        '*.yara',
    },
    callback = function()
        if not buf_is_empty() then
            return
        end
        local filepath = fn.expand('%:p')
        local hdr = header.make_header(filepath, '//')
        api.nvim_buf_set_lines(0, 0, 0, false, hdr)
        vim.cmd('normal! G')
    end,
})

local REPLACEMENTS = {}

---Modernize deprecated yara syntax in the current buffer.
function M.modernize()
    modernize.buffer('yara', REPLACEMENTS, 'yara')
end

return M
