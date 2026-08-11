-- #################################################################
-- /qompassai/lua/scip/indexers/typescript.lua
-- Qompass AI SCIP TypeScript Indexer
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

---Return whether a project contains a TypeScript or JavaScript configuration.
---@param root string Project root.
---@return boolean
local function has_tsconfig(root)
        return utils.path_exists(
                fs.joinpath(root, 'tsconfig.json')
        )
                or utils.path_exists(
                        fs.joinpath(root, 'jsconfig.json')
                )
end

---Return whether the project is configured as a pnpm workspace.
---@param root string Project root.
---@return boolean
local function has_pnpm_workspace(root)
        return utils.path_exists(
                fs.joinpath(root, 'pnpm-workspace.yaml')
        )
                or utils.path_exists(
                        fs.joinpath(root, 'pnpm-workspace.yml')
                )
end

---Return whether a package.json declares Yarn/npm-style workspaces.
---
---This deliberately performs only a lightweight JSON inspection. Invalid
---package.json content falls back to normal SCIP configuration detection.
---
---@param root string Project root.
---@return boolean
local function has_package_workspaces(root)
        local package_json = fs.joinpath(
                root,
                'package.json'
        )

        if not utils.path_exists(package_json) then
                return false
        end

        local file = io.open(package_json, 'r')

        if file == nil then
                return false
        end

        local content = file:read('*a')

        file:close()

        if content == nil or content == '' then
                return false
        end

        local ok, decoded = pcall(
                vim.json.decode,
                content
        )

        if not ok or type(decoded) ~= 'table' then
                return false
        end

        return decoded.workspaces ~= nil
end

---Build scip-typescript arguments for the current project.
---
---Resolution order:
---
---1. pnpm workspace
---2. package.json workspace
---3. existing tsconfig/jsconfig
---4. inferred configuration
---
---Explicit workspace modes are preferred when their project metadata clearly
---indicates that structure.
---
---@param context ScipContext SCIP indexing context.
---@return string[] args Arguments passed to scip-typescript.
local function args(context)
        local project_root = context.root

        if has_pnpm_workspace(project_root) then
                return {
                        'index',
                        '--pnpm-workspaces',
                }
        end

        if has_package_workspaces(project_root) then
                return {
                        'index',
                        '--yarn-workspaces',
                }
        end

        if has_tsconfig(project_root) then
                return {
                        'index',
                }
        end

        return {
                'index',
                '--infer-tsconfig',
        }
end

---@type ScipIndexer
local indexer = {
        args = args,

        command = 'scip-typescript',

        filetypes = {
                javascript = true,
                javascriptreact = true,
                typescript = true,
                typescriptreact = true,
        },

        markers = {
                '.git',
                'bun.lock',
                'bun.lockb',
                'deno.json',
                'deno.jsonc',
                'jsconfig.json',
                'package.json',
                'pnpm-lock.yaml',
                'pnpm-workspace.yaml',
                'tsconfig.json',
                'yarn.lock',
        },
}

return indexer
