-- Native LSP completion; chat/provider plugins are not loaded by this module.
-- SPDX-License-Identifier: Apache-2.0
local core = require('mappings._core')
local M = {}
local OWNER = 'aimap'

local function attach(bufnr)
    local maps = {}
    if core.source(bufnr) and core.supports(bufnr, 'textDocument/completion') then
        maps[#maps + 1] = {
            lhs = '<C-Space>',
            mode = 'i',
            desc = 'Request LSP completion',
            rhs = function()
                vim.lsp.completion.get()
            end,
        }
    end
    if core.source(bufnr) and core.supports(bufnr, 'textDocument/inlineCompletion') then
        maps[#maps + 1] = {
            lhs = '<M-CR>',
            mode = 'i',
            expr = true,
            desc = 'Accept inline completion',
            rhs = function()
                if vim.lsp.inline_completion.get({ bufnr = bufnr }) then
                    return ''
                end
                return '<M-CR>'
            end,
        }
        maps[#maps + 1] = {
            lhs = '<M-]>',
            mode = 'i',
            desc = 'Next inline completion',
            rhs = function()
                vim.lsp.inline_completion.select({ bufnr = bufnr, count = 1 })
            end,
        }
        maps[#maps + 1] = {
            lhs = '<M-[>',
            mode = 'i',
            desc = 'Previous inline completion',
            rhs = function()
                vim.lsp.inline_completion.select({ bufnr = bufnr, count = -1 })
            end,
        }
        maps[#maps + 1] = {
            lhs = '<LocalLeader>ai',
            desc = 'Toggle inline completion',
            rhs = function()
                local filter = { bufnr = bufnr }
                local enabled = vim.lsp.inline_completion.is_enabled(filter)
                vim.lsp.inline_completion.enable(not enabled, filter)
            end,
        }
    end
    core.install(OWNER, bufnr, maps)
end

function M.setup()
    core.watch(OWNER, attach)
end
function M.teardown()
    core.teardown(OWNER)
end
M.setup_aimap = M.setup
return M
