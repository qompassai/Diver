-- #################################################################
-- /qompassai/lua/scip/indexers/zig.lua
-- Qompass AI SCIP Zig Indexer
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

---@type string[]
local source_candidates = {
        'src/main.zig',
        'src/lib.zig',
        'main.zig',
        'lib.zig',
}

---Return a filesystem-safe project/package name.
---
---scip-zig requires both `--pkg` and `--root-pkg`. The repository directory
---name provides a deterministic fallback without requiring additional project
---configuration.
---
---@param root string Project root.
---@return string
local function package_name(root)
        local normalized = fs.normalize(root)
        local name = fs.basename(normalized)

        if name == nil or name == '' then
                return 'root'
        end

        return name
end

---Find the root Zig source file.
---
---Conventional executable and library entrypoints are checked in priority
---order. If none exist, the current Zig buffer is used when it belongs to the
---same project.
---
---@param context ScipContext SCIP indexing context.
---@return string
local function root_source(context)
        for _, relative in ipairs(source_candidates) do
                local candidate = fs.joinpath(
                        context.root,
                        relative
                )

                if utils.path_exists(candidate) then
                        return candidate
                end
        end

        if
                context.filename ~= ''
                and context.filename:match('%.zig$') ~= nil
                and utils.path_exists(context.filename)
        then
                return context.filename
        end

        error(
                'No Zig root source file found under '
                        .. context.root
                        .. '. Expected src/main.zig, src/lib.zig, '
                        .. 'main.zig, or lib.zig.'
        )
end

---Build arguments for scip-zig.
---
---scip-zig requires an explicit project root, package declaration, source
---entrypoint, and root-package declaration.
---
---@param context ScipContext SCIP indexing context.
---@return string[]
local function args(context)
        local package = package_name(context.root)
        local source = root_source(context)

        return {
                '--root-path',
                context.root,
                '--pkg',
                package,
                source,
                '--root-pkg',
                package,
        }
end

---@type ScipIndexer
local indexer = {
        args = args,

        command = 'scip-zig',

        filetypes = {
                zig = true,
        },

        markers = {
                '.git',
                'build.zig',
                'build.zig.zon',
        },
}

return indexer
