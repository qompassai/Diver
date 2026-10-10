-- /qompassai/Diver/lua/config/lang/opencl.lua
-- Qompass AI Diver OpenCL Lang Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Tooling (verified 2026-10-10): the language server is the
-- Galarius opencl-language-server (lsp/opencl_ls.lua, enabled
-- centrally); it needs an enumeratable OpenCL device and reports
-- cleanly when none exists. The formatters catalog formats the
-- opencl filetype with clang_format; style follows the C discipline
-- (TIGER_STYLE_C.md). No linter is catalogued for opencl and no
-- treesitter parser is installed. No credible language-specific
-- MCP server or package-publish flow exists for OpenCL kernels,
-- so none is declared here.
local M = {}
local api = vim.api
local fn = vim.fn
local group = api.nvim_create_augroup('OpenCL', {
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
        '*.cl',
        '*.clh',
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

---Modernize deprecated opencl syntax in the current buffer.
function M.modernize()
    modernize.buffer('opencl', REPLACEMENTS, 'opencl')
end

return M
