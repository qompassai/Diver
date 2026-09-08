-- #################################################################
-- /qompassai/lua/scip/indexers/php.lua
-- Qompass AI SCIP PHP Indexer
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

---Resolve the scip-php executable for the current project.
---
---Composer projects may install scip-php locally under `vendor/bin`.
---The project-local executable is preferred so the indexer version follows
---the project's dependency lockfile rather than an unrelated global version.
---
---If no project-local executable exists, the globally available `scip-php`
---command is used instead.
---
---@param context ScipContext SCIP indexing context.
---@return string command Resolved scip-php executable.
local function command(context)
        local local_command = fs.joinpath(
                context.root,
                'vendor',
                'bin',
                'scip-php'
        )

        if utils.path_exists(local_command) then
                return local_command
        end

        return 'scip-php'
end

---Build command-line arguments for scip-php.
---
---scip-php discovers Composer/project configuration from the working
---directory supplied by the native SCIP runner, so no additional arguments
---are required for the normal project-indexing case.
---
---@param _context ScipContext SCIP indexing context.
---@return string[] args Arguments passed to scip-php.
local function args(_context)
        return {}
end

---@type ScipIndexer
local indexer = {
        args = args,

        command = command,

        filetypes = {
                php = true,
        },

        markers = {
                '.git',
                'composer.json',
                'composer.lock',
        },
}

return indexer
