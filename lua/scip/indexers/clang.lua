-- #################################################################
-- /qompassai/lua/scip/indexers/clang.lua
-- Qompass AI SCIP Clang Indexer
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

local fs = vim.fs

local utils = require('scip.utils')

---Locate the compilation database used by scip-clang.
---
---The compilation database describes the exact compiler invocation for each
---translation unit and is required for accurate C/C++/Objective-C indexing.
---
---@param context QompassScipContext SCIP indexing context.
---@return string[] args Arguments passed to scip-clang.
local function args(context)
        return {
                '--compdb-path='
                        .. utils.compilation_database(context.root),
        }
end

---@type QompassScipIndexer
local indexer = {
        args = args,

        command = 'scip-clang',

        filetypes = {
                c = true,
                cpp = true,
                cuda = true,
                objc = true,
                objcpp = true,
        },

        markers = {
                '.git',
                'CMakeLists.txt',
                'compile_commands.json',
                'meson.build',
        },
}

return indexer
