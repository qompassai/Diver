-- virtual.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
--require("utils.virtual").setup_len_hints(100)
local ns = vim.api.nvim_create_namespace('utils_virtual')
---@param bufnr integer|nil
---@param lnum integer           -- 0-based line
---@param text string
---@param hl string|nil          -- highlight group
function M.inline_hint(bufnr, lnum, text, hl)
    bufnr = bufnr or 0
    hl = hl or 'Comment'
    return vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, -1, {
        virt_text = {
            {
                text,
                hl,
            },
        },
        virt_text_pos = 'eol',
    })
end

---@param bufnr integer|nil
---@param lnum integer
---@param text string
---@param hl string|nil
function M.code_lens(bufnr, lnum, text, hl)
    bufnr = bufnr or 0
    hl = hl or 'DiagnosticHint'
    return vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, 0, {
        virt_text = {
            {
                text,
                hl,
            },
        },
        virt_text_pos = 'overlay',
    })
end

---@param bufnr integer|nil
function M.clear(bufnr)
    bufnr = bufnr or 0
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

function M.setup_len_hints(maxlen)
    maxlen = maxlen or 80
    vim.api.nvim_create_autocmd({
        'BufEnter',
        'TextChanged',
        'TextChangedI',
    }, {
        group = vim.api.nvim_create_augroup('UtilsVirtualLenHints', {
            clear = true,
        }),
        callback = function(args)
            local buf = args.buf
            if not vim.api.nvim_buf_is_loaded(buf) then
                return
            end
            M.clear(buf)
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            for i, line in ipairs(lines) do
                local len = #line
                if len > maxlen then
                    M.inline_hint(buf, i - 1, string.format(' %d chars', len), 'WarningMsg')
                end
            end
        end,
    })
end

return M
