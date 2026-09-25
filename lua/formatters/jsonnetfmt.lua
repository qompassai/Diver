-- #################################################################
-- /qompassai/lua/formatters/jsonnetfmt.lua
-- Qompass AI Diver jsonnetfmt Native Formatter Spec
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
-- #################################################################
---@param context FormatterContext
---@return string
local function working_directory(context)
    if context.filename ~= '' then
        local directory = vim.fs.dirname(context.filename)
        if directory then
            return directory
        end
    end
    return context.root
end

---@type FormatterSpec
return {
    cmd = 'jsonnetfmt',
    args = {
        '--indent',
        '2',
        '--max-blank-lines',
        '2',
        '--string-style',
        's',
        '--comment-style',
        's',
        '--pretty-field-names',
        '--no-pad-arrays',
        '--pad-objects',
        '--sort-imports',
        '--use-implicit-plus',
        '-',
    },
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        'jsonnetfile.json',
        'jsonnetfile.lock.json',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'jsonnet',
}
