-- #################################################################
-- /qompassai/diver/lua/security/mask.lua
-- Qompass AI Diver Secret Masking
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
---Secret masking for screen sharing — overlays secret values with `********`.
---
---Plain-language version: when you share your screen, `.env` files and API
---keys are visible to everyone watching. This module covers the secret
---values with asterisks. The file itself is never modified.
---
---HONEST SECURITY MODEL: this covers the SCREEN ONLY. It does not stop
---LSP servers, AI tools, the clipboard, or `:w` from seeing the values.
---It is for screen-sharing and streaming — not a vault, not redaction.
---For files that must never enter the session at all, see security.guard.
---@module 'security.mask'

local M = {}

local api = vim.api
local fn = vim.fn

---Per-buffer masking state. Keyed by bufnr, cleared on BufWipeout.
---@type table<integer, boolean>
local masked = {}

local AUGROUP = 'diver_secret_mask'
local MASK_TEXT = '********'
local NS = api.nvim_create_namespace('diver_secret_mask')
local setup_done = false

---Value patterns per file extension. Each entry: { value_pattern, key_hint }.
---The overlay covers the VALUE range only; keys stay readable.
local PATTERNS = {
    -- .env-style: KEY=value (value = rest of line, minus quotes)
    env = { '^%s*[%a_][%w_]*%s*=%s*()[^%s#]+()' },
    -- JSON: "key": "value" where the key looks secret-ish
    json = {
        '"[%w_%-]*[Aa][Pp][Ii][_%-]?[Kk][Ee][Yy][%w_%-]*"%s*:%s*"()[^"]*()"',
        '"[%w_%-]*[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][%w_%-]*"%s*:%s*"()[^"]*()"',
        '"[%w_%-]*[Ss][Ee][Cc][Rr][Ee][Tt][%w_%-]*"%s*:%s*"()[^"]*()"',
        '"[%w_%-]*[Tt][Oo][Kk][Ee][Nn][%w_%-]*"%s*:%s*"()[^"]*()"',
    },
    -- shell-style: KEY=value (value = rest of line, minus quotes)
    sh = { '^%s*[%a_][%w_]*%s*=%s*()[^%s#]+()' },
    -- TOML: key = "value" where the key looks secret-ish
    toml = {
        '[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]%s*=%s*"()[^"]*()"',
        '[Ss][Ee][Cc][Rr][Ee][Tt]%s*=%s*"()[^"]*()"',
        '[Tt][Oo][Kk][Ee][Nn]%s*=%s*"()[^"]*()"',
    },
    -- YAML: key: value where the key looks secret-ish
    yaml = {
        '[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]%s*:%s*()[^%s#]+()',
        '[Ss][Ee][Cc][Rr][Ee][Tt]%s*:%s*()[^%s#]+()',
        '[Tt][Oo][Kk][Ee][Nn]%s*:%s*()[^%s#]+()',
    },
    yml = {
        '[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]%s*:%s*()[^%s#]+()',
        '[Ss][Ee][Cc][Rr][Ee][Tt]%s*:%s*()[^%s#]+()',
        '[Tt][Oo][Kk][Ee][Nn]%s*:%s*()[^%s#]+()',
    },
}

---@param bufnr integer
---@return string file extension, lowercased, without dot
local function ext_of(bufnr)
    local name = api.nvim_buf_get_name(bufnr)
    -- Dotfiles like .env have no :e extension; match by basename instead.
    if fn.fnamemodify(name, ':t'):match('^%.env') then
        return 'env'
    end
    return fn.fnamemodify(name, ':e'):lower()
end

---Place mask overlays over every secret value in the buffer.
---@param bufnr integer
local function apply_masks(bufnr)
    if not api.nvim_buf_is_valid(bufnr) then
        return
    end
    api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
    local ext = ext_of(bufnr)
    local patterns = PATTERNS[ext]
    if not patterns then
        return
    end
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for lnum, line in ipairs(lines) do
        for _, pat in ipairs(patterns) do
            local s, e = line:match(pat)
            -- s/e are the () positions: 1-based start, 1-based end-exclusive.
            if s ~= nil and e ~= nil and e > s then
                api.nvim_buf_set_extmark(bufnr, NS, lnum - 1, s - 1, {
                    end_row = lnum - 1,
                    end_col = e - 1,
                    virt_text = { { MASK_TEXT, 'Comment' } },
                    virt_text_pos = 'overlay',
                    hl_mode = 'combine',
                })
            end
        end
    end
end

---@param bufnr integer
---@return boolean
function M.is_masked(bufnr)
    return masked[bufnr] == true
end

---Wire up masking. Idempotent.
function M.setup()
    if setup_done then
        return M
    end
    setup_done = true

    api.nvim_create_augroup(AUGROUP, { clear = true })
    api.nvim_create_autocmd('BufWipeout', {
        callback = function(args)
            masked[args.buf] = nil
        end,
        desc = 'Drop mask state with the buffer',
        group = AUGROUP,
    })
    api.nvim_create_autocmd('TextChanged', {
        callback = function(args)
            if masked[args.buf] then
                apply_masks(args.buf)
            end
        end,
        desc = 'Re-apply secret masks after edits',
        group = AUGROUP,
    })
    api.nvim_create_user_command('MaskToggle', function()
        M.toggle()
    end, { desc = 'Toggle secret masking for the current buffer (screen only)' })

    return M
end

---Toggle masking for a buffer.
---@param bufnr? integer defaults to current buffer
function M.toggle(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    assert(api.nvim_buf_is_valid(bufnr), 'security.mask.toggle: invalid buffer')
    if masked[bufnr] then
        masked[bufnr] = nil
        api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
        vim.notify('[mask] Revealed (buffer text was never modified)', vim.log.levels.INFO)
    else
        masked[bufnr] = true
        apply_masks(bufnr)
        vim.notify('[mask] Secrets masked on screen only — file unchanged', vim.log.levels.INFO)
    end
end

return M
