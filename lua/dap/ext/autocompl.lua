-- #################################################################
-- /qompassai/lua/dap/ext/autocompl.lua
-- Qompass AI Autocompl
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
local M = {}
local api = vim.api
local notify = require('dap.utils').notify

---Pending completion timer per buffer. A single module-global timer let one
---buffer's InsertLeave kill another buffer's pending completion, so each
---attached buffer owns its timer here.
---@type table<integer, uv.uv_timer_t?>
local timers = {}

---@param buf integer buffer whose pending completion timer to destroy
local function destroy_timer(buf)
    local timer = timers[buf]
    if timer then
        timer:stop()
        timer:close()
        timers[buf] = nil
    end
end

---@param buf integer buffer the completion was triggered for
local function trigger_completion(buf)
    destroy_timer(buf)
    if api.nvim_get_current_buf() == buf then
        api.nvim_feedkeys(api.nvim_replace_termcodes('<C-x><C-o>', true, false, true), 'm', true)
    end
end

function M._InsertCharPre()
    local buf = api.nvim_get_current_buf()
    if timers[buf] then
        return
    end
    if tonumber(vim.fn.pumvisible()) == 1 then
        return
    end
    local char = api.nvim_get_vvar('char')
    local session = require('dap').session()
    local trigger_characters = ((session or {}).capabilities or {}).completionTriggerCharacters
    local triggers
    if trigger_characters and next(trigger_characters) then
        triggers = trigger_characters
    else
        triggers = { '.' }
    end
    if vim.tbl_contains(triggers, char) then
        local new_timer = vim.uv.new_timer()
        if new_timer then
            timers[buf] = new_timer
            new_timer:start(
                50,
                0,
                vim.schedule_wrap(function()
                    trigger_completion(buf)
                end)
            )
        end
    end
end

function M._InsertLeave()
    destroy_timer(api.nvim_get_current_buf())
end

function M.attach(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    if api.nvim_create_autocmd then
        local group = api.nvim_create_augroup(
            ('dap.ext.autocompl-%d'):format(bufnr),
            { clear = true }
        )
        api.nvim_create_autocmd('InsertCharPre', {
            group = group,
            buffer = bufnr,
            callback = function()
                local ok, err = pcall(M._InsertCharPre)
                if not ok then
                    notify('dap.ext.autocompl: ' .. tostring(err), vim.log.levels.ERROR)
                end
            end,
        })
        api.nvim_create_autocmd('InsertLeave', {
            group = group,
            buffer = bufnr,
            callback = function()
                M._InsertLeave()
            end,
        })
    else
        vim.cmd(string.format(
            [[
      augroup dap_autocomplete-%d
      au!
      autocmd InsertCharPre <buffer=%d> lua require('dap.ext.autocompl')._InsertCharPre()
      autocmd InsertLeave <buffer=%d> lua require('dap.ext.autocompl')._InsertLeave()
      augroup end
      ]],
            bufnr,
            bufnr,
            bufnr
        ))
    end
end

return M
