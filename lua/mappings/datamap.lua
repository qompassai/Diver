-- Filetype-local math annotations and query templates; no preview plugins.
-- SPDX-License-Identifier: Apache-2.0
local api = vim.api
local core = require('mappings._core')
local M = {}
local OWNER = 'datamap'
local LINE_COUNT_MAX = 10000
local LINE_BYTES_MAX = 8192
local namespace = api.nvim_create_namespace('native_mapping_math')
local FILETYPES = { markdown = true, plaintex = true, rmd = true, tex = true }

local function expression(line)
    if #line > LINE_BYTES_MAX then
        return nil
    end
    -- Annotation only: this intentionally does not claim to typeset TeX.
    return line:match('%$%$(.-)%$%$')
        or line:match('%$(.-)%$')
        or line:match('\\%((.-)\\%)')
        or line:match('\\%[(.-)\\%]')
end

local function annotate(bufnr, row, line)
    local text = expression(line)
    if text and text ~= '' then
        api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
            virt_text = { { ' math: ' .. text, 'Comment' } },
            virt_text_pos = 'eol',
        })
    end
end

local function all_math(bufnr)
    api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    local count = api.nvim_buf_line_count(bufnr)
    if count > LINE_COUNT_MAX then
        core.notify('Math annotation limit: ' .. LINE_COUNT_MAX .. ' lines')
        return
    end
    for index, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        annotate(bufnr, index - 1, line)
    end
end

local function line_math(bufnr)
    local row = api.nvim_win_get_cursor(0)[1] - 1
    local marks = api.nvim_buf_get_extmarks(bufnr, namespace, { row, 0 }, { row, -1 }, {})
    api.nvim_buf_clear_namespace(bufnr, namespace, row, row + 1)
    if #marks == 0 then
        annotate(bufnr, row, api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or '')
    end
end

local function attach(bufnr)
    local maps = {}
    local filetype = vim.bo[bufnr].filetype
    if core.source(bufnr) and FILETYPES[filetype] then
        maps = {
            {
                lhs = '<LocalLeader>ma',
                rhs = function()
                    all_math(bufnr)
                end,
                desc = 'Annotate math expressions',
            },
            {
                lhs = '<LocalLeader>mc',
                rhs = function()
                    api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
                end,
                desc = 'Clear math annotations',
            },
            {
                lhs = '<LocalLeader>ml',
                rhs = function()
                    line_math(bufnr)
                end,
                desc = 'Toggle line math annotation',
            },
        }
    else
        api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    end
    local command = ({ soql = 'SfSoqlTemplate', sosl = 'SfSoslTemplate' })[filetype]
    if command and vim.fn.exists(':' .. command) == 2 then
        maps[#maps + 1] = {
            lhs = '<LocalLeader>mq',
            rhs = core.command(command),
            desc = 'Query template for ' .. filetype,
        }
    end
    core.install(OWNER, bufnr, maps)
end

function M.setup()
    core.watch(OWNER, attach, { 'BufEnter', 'FileType' })
end
function M.teardown()
    core.teardown(OWNER)
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if core.usable(bufnr) then
            api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
        end
    end
end
M.setup_datamap = M.setup
M.setup_sf_query_maps = M.setup
return M
