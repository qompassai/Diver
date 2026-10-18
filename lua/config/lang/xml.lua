-- /qompassai/Diver/lua/config/lang/xml.lua
-- Qompass AI Diver XML Lang Config
---@module 'config.lang.xml'
-- Tooling (verified 2026-10-10): the language server is LemMinX
-- (lsp/lemminx_ls.lua, enabled centrally); it provides validation,
-- completion, and formatting. The formatters catalog pretty-prints
-- the xml filetype with xmlformat and xmllint. No linter is
-- catalogued for xml and the treesitter xml parser is installed.
-- No credible language-specific MCP server or package-publish flow
-- exists for XML documents, so none is declared here.
local M = {}
local api = vim.api
local fn = vim.fn
local group = api.nvim_create_augroup('XML', {
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
        '*.xml',
        '*.xsd',
        '*.xsl',
        '*.xslt',
    },
    callback = function()
        if not buf_is_empty() then
            return
        end
        local filepath = fn.expand('%:p')
        local hdr = header.make_header(filepath, '<!--')
        api.nvim_buf_set_lines(0, 0, 0, false, hdr)
        vim.cmd('normal! G')
    end,
})

local REPLACEMENTS = {}

---Modernize deprecated xml syntax in the current buffer.
function M.modernize()
    modernize.buffer('xml', REPLACEMENTS, 'xml')
end

return M
