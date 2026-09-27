-- #################################################################
-- /qompassai/Diver/lua/games/aseprite/prompts.lua
-- Qompass AI Aseprite AI-Art Prompt Builder
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
-- Builds copyright-safe AI image prompts for sprite art. Every emitted
-- prompt describes an ORIGINAL character and generic pixel-art style
-- language only: it never names existing franchises or characters.
-- A forbidden-token screen refuses to emit any prompt containing one.
--
-- Pure functions (build_prompt, screen_forbidden, default_opts) carry
-- no vim dependency and are unit-testable under plain Lua. The
-- interactive builder needs a live Neovim (vim.ui, registers).
local config = require('games.aseprite.config')

local M = {}

M.FORBIDDEN_TOKENS_MAX = 64

---@class AsepriteSpritePromptOpts
---@field concept string Original character concept, 1-3 sentences
---@field palette string Comma-separated palette description
---@field pose string Pose description
---@field style string Pixel-art style descriptor
---@field background string Background instruction
---@field extra string Optional extra directives (may be empty)

---Default prompt options. Pure: no vim access.
---@return AsepriteSpritePromptOpts
function M.default_opts()
    local prompt_cfg = config.sprite_prompt or {}
    return {
        concept = '',
        palette = '',
        pose = 'dynamic fighting stance, full body',
        style = prompt_cfg.default_style or 'detailed 16-bit pixel art game sprite, clean cel-shaded pixels',
        background = 'solid black background',
        extra = '',
    }
end

---Screen text against the forbidden-token list (existing franchises /
---characters the designs must not copy). Pure: no vim access.
---
---Returns nil when clean, or the first offending token found.
---@param text string
---@return string|nil offending token, or nil when clean
function M.screen_forbidden(text)
    if type(text) ~= 'string' or text == '' then
        return nil
    end
    local tokens = (config.sprite_prompt or {}).forbidden_tokens or {}
    local lowered = text:lower()
    local checked = 0
    for _, token in ipairs(tokens) do
        checked = checked + 1
        if checked > M.FORBIDDEN_TOKENS_MAX then
            break
        end
        if type(token) == 'string' and token ~= '' and lowered:find(token:lower(), 1, true) then
            return token
        end
    end
    return nil
end

---Validate prompt options. Pure: no vim access.
---@param opts AsepriteSpritePromptOpts
---@return boolean ok
---@return string|nil err
function M.validate_opts(opts)
    if type(opts) ~= 'table' then
        return false, 'opts must be a table'
    end
    if type(opts.concept) ~= 'string' or opts.concept:match('^%s*$') then
        return false, 'concept is required (describe your ORIGINAL character)'
    end
    if #opts.concept > 2000 then
        return false, 'concept exceeds 2000 characters'
    end
    for _, field in ipairs({ 'palette', 'pose', 'style', 'background', 'extra' }) do
        local value = opts[field]
        if value ~= nil and type(value) ~= 'string' then
            return false, field .. ' must be a string'
        end
        if type(value) == 'string' and #value > 2000 then
            return false, field .. ' exceeds 2000 characters'
        end
    end
    return true, nil
end

---Build a copyright-safe sprite prompt. Pure: no vim access.
---
---Returns nil + error when opts are invalid or any field trips the
---forbidden-token screen.
---@param opts AsepriteSpritePromptOpts
---@return string|nil prompt
---@return string|nil err
function M.build_prompt(opts)
    local ok, err = M.validate_opts(opts)
    if not ok then
        return nil, err
    end
    local parts = {
        'Original character design. Do not copy any existing game, anime, or comic character.',
        opts.concept,
    }
    if opts.pose and opts.pose:match('%S') then
        parts[#parts + 1] = 'Pose: ' .. opts.pose .. '.'
    end
    if opts.palette and opts.palette:match('%S') then
        parts[#parts + 1] = 'Palette: ' .. opts.palette .. '.'
    end
    if opts.style and opts.style:match('%S') then
        parts[#parts + 1] = 'Style: ' .. opts.style .. '.'
    end
    if opts.background and opts.background:match('%S') then
        parts[#parts + 1] = opts.background .. ', single character centered.'
    end
    parts[#parts + 1] = 'No text, no watermark, no signature.'
    if opts.extra and opts.extra:match('%S') then
        parts[#parts + 1] = opts.extra
    end
    local prompt = table.concat(parts, ' ')
    local bad = M.screen_forbidden(prompt)
    if bad then
        return nil,
            'prompt blocked: references forbidden material (' .. bad .. '). Rewrite the concept in your own words.'
    end
    return prompt, nil
end

---Copy text to the system clipboard. Returns nil + err when unavailable.
---@param text string
---@return boolean ok
---@return string|nil err
local function copy_to_clipboard(text)
    if vim.fn.has('clipboard') ~= 1 then
        return false, 'no clipboard provider'
    end
    vim.fn.setreg('+', text)
    return true, nil
end

---Open text in a scratch buffer for review / manual copy.
---@param title string
---@param text string
local function open_scratch(title, text)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, '\n'))
    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
    vim.api.nvim_set_option_value('filetype', 'markdown', { buf = buf })
    vim.api.nvim_set_current_buf(buf)
    vim.notify(title, vim.log.levels.INFO)
end

---Interactive prompt builder: asks for concept/palette/pose, then shows
---the screened prompt in a scratch buffer and copies it when possible.
function M.interactive_builder()
    local opts = M.default_opts()
    opts.concept = vim.fn.input('Character concept (ORIGINAL design, 1-3 sentences): ')
    if opts.concept:match('^%s*$') then
        vim.notify('Aseprite: prompt builder cancelled (empty concept).', vim.log.levels.WARN)
        return
    end
    local palette = vim.fn.input('Palette (e.g. "amber #ffd166, slate #1c2541"): ')
    if palette:match('%S') then
        opts.palette = palette
    end
    local pose = vim.fn.input('Pose [' .. opts.pose .. ']: ')
    if pose:match('%S') then
        opts.pose = pose
    end
    local prompt, err = M.build_prompt(opts)
    if not prompt then
        vim.notify('Aseprite: ' .. tostring(err), vim.log.levels.ERROR)
        return
    end
    local copied = copy_to_clipboard(prompt)
    open_scratch(
        copied and 'Aseprite: prompt copied to clipboard (+ scratch buffer below)'
            or 'Aseprite: prompt ready (clipboard unavailable — yank from scratch buffer)',
        prompt
    )
end

return M
