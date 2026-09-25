-- #################################################################
-- /qompassai/Diver/lua/formatters/dioxus.lua
-- Qompass AI Diver Native Dioxus RSX Formatter
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
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
---@source https://github.com/DioxusLabs/dioxus
---@source https://dioxuslabs.com/learn/0.7/guides/tools/
---@param context FormatterContext
---@return string
local function working_directory(context)
    local root = context.root
    if root == '' then
        error('dioxus: formatter context has an empty project root')
    end
    return vim.fs.normalize(root)
end

---@type FormatterSpec
return {
    cmd = 'dx',

    args = {
        'fmt',
        '-f',
        '-',
    },
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        'Dioxus.toml',
        'dioxus.toml',
        'Cargo.toml',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },

    exit_codes = {
        0,
    },
    automatic = true,
    allow_empty = false,
    extension = 'rs',
}
