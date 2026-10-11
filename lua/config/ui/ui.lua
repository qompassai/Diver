-- #################################################################
-- /qompassai/diver/lua/utils/ux/ui.lua
-- Qompass AI UX-UI Utils
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
local transparency = require('config.ui.transparency')
local virtual_text = require('config.ui.vt')
M.clear = virtual_text.clear
M.code_lens = virtual_text.code_lens
M.disable_transparency = transparency.disable
M.enable_transparency = transparency.enable
M.inline_hint = virtual_text.inline_hint
function M.setup(opts)
    opts = opts or {}

    if opts.len_hints then
        virtual_text.setup({
            len_hints = opts.len_hints,
        })
    end

    if opts.transparency then
        transparency.setup(opts.transparency)
    end
end
M.setup_len_hints = virtual_text.setup_len_hints
M.setup_transparency = transparency.setup
M.toggle_transparency = transparency.toggle
M.transparency = transparency
M.virtual_text = virtual_text
return M
