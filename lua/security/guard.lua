-- #################################################################
-- /qompassai/diver/lua/security/guard.lua
-- Qompass AI Diver Sensitive File Guard
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
-- SPDX-FileCopyrightText: 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
-- vim: ts=4 sw=4 sts=4 et
---Sensitive-file guard — refuses to let secrets into the editor session.
---
---Plain-language version: some files should never be opened in a full
---Neovim session — SSH keys, cloud credentials, tokens. If they load,
---plugins, LSP servers, AI tools, and session snapshots can all see them.
---This module wipes those buffers at read time, before anything else runs.
---
---Security model: this is a seatbelt, not a vault. It stops accidental
---exposure inside this editor. It does not protect secrets from anything
---outside Neovim, and a user can always bypass it with `nvim -u NONE`.
---@module 'security.guard'

local M = {}

local api = vim.api
local fn = vim.fn

---Master switch. Set false to open a sensitive file deliberately.
---(Still prefer `nvim -u NONE` for intentional secret edits.)
M.enabled = true

---Glob patterns (matched against the absolute path) treated as sensitive.
---Deliberately broad: a false positive costs one bypass, a false negative
---costs a leaked secret.
---@type string[]
M.patterns = {
    '*.env',
    '*.env.*',
    '*.key',
    '*.p12',
    '*.pem',
    '*.pfx',
    '*credential*',
    '*secret*',
    '*token*',
    '*/.aws/*',
    '*/.azure/*',
    '*/.config/gcloud/*',
    '*/.gnupg/*',
    '*/.ssh/*',
}

local AUGROUP = 'diver_security_guard'
local setup_done = false

---@param path string absolute file path
---@return boolean true when the path matches a sensitive pattern
---@nodiscard
function M.is_sensitive(path)
    assert(type(path) == 'string', 'security.guard.is_sensitive: path must be a string')
    if path == '' then
        return false
    end
    for _, pattern in ipairs(M.patterns) do
        if fn.match(path, fn.glob2regpat(pattern)) >= 0 then
            return true
        end
    end
    return false
end

---Wire up the guard. Idempotent.
function M.setup()
    if setup_done then
        return M
    end
    setup_done = true

    -- Buffers marked sensitive during BufReadPre. Vim forbids deleting a
    -- buffer inside *ReadPre (E201), so we mark there and wipe in
    -- BufReadPost — which still fires before FileType, so no filetype
    -- detection, LSP, AI tool, or session snapshot ever sees the content.
    ---@type table<integer, string>
    local pending_wipe = {}

    api.nvim_create_augroup(AUGROUP, { clear = true })
    api.nvim_create_autocmd('BufReadPost', {
        callback = function(args)
            local path = pending_wipe[args.buf]
            if path == nil then
                return
            end
            pending_wipe[args.buf] = nil
            if api.nvim_buf_is_valid(args.buf) then
                api.nvim_buf_delete(args.buf, { force = true })
            end
            vim.notify(
                ('[guard] Refused sensitive file: %s\nOpen with `nvim -u NONE` if intentional.'):format(
                    fn.fnamemodify(path, ':~')
                ),
                vim.log.levels.WARN
            )
        end,
        desc = 'Wipe marked sensitive buffers before FileType/LSP runs',
        group = AUGROUP,
    })
    api.nvim_create_autocmd('BufReadPre', {
        callback = function(args)
            if not M.enabled then
                return
            end
            local path = fn.fnamemodify(args.file, ':p')
            if M.is_sensitive(path) then
                pending_wipe[args.buf] = path
            end
        end,
        desc = 'Mark sensitive files for wipe before plugins/LSP/AI see them',
        group = AUGROUP,
    })
    api.nvim_create_autocmd('BufWipeout', {
        callback = function(args)
            pending_wipe[args.buf] = nil
        end,
        desc = 'Drop pending guard marks with the buffer',
        group = AUGROUP,
    })

    api.nvim_create_user_command('GuardToggle', function()
        M.enabled = not M.enabled
        vim.notify(
            ('[guard] %s'):format(M.enabled and 'enabled' or 'DISABLED — sensitive files will open'),
            M.enabled and vim.log.levels.INFO or vim.log.levels.WARN
        )
    end, { desc = 'Toggle the sensitive-file guard' })

    return M
end

return M
