-- #################################################################
-- /qompassai/lua/scip/indexers/java.lua
-- Qompass AI SCIP Java Indexer
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

---Return whether a project contains a path.
---@param root string Project root.
---@param name string Relative path.
---@return boolean
local function has(root, name)
        return utils.path_exists(
                fs.joinpath(root, name)
        )
end

---Detect the JVM project's build tool.
---
---scip-java supports Gradle, Maven, and sbt project layouts. Explicit build
---tool selection makes indexing more predictable when multiple metadata files
---exist in a repository.
---
---@param root string Project root.
---@return 'gradle'|'maven'|'sbt'|nil
local function build_tool(root)
        if
                has(root, 'build.gradle')
                or has(root, 'build.gradle.kts')
                or has(root, 'gradlew')
                or has(root, 'settings.gradle')
                or has(root, 'settings.gradle.kts')
        then
                return 'gradle'
        end

        if has(root, 'pom.xml') then
                return 'maven'
        end

        if
                has(root, 'build.sbt')
                or has(root, 'project/build.properties')
        then
                return 'sbt'
        end

        return nil
end

---Build arguments for scip-java.
---
---The index subcommand generates `index.scip` in the project working
---directory. When the build system can be identified, it is passed
---explicitly rather than relying on ambiguous auto-detection.
---
---@param context ScipContext SCIP indexing context.
---@return string[] args Arguments passed to scip-java.
local function args(context)
        local arguments = {
                'index',
        }

        local tool = build_tool(context.root)

        if tool ~= nil then
                arguments[#arguments + 1] = '--build-tool=' .. tool
        end

        return arguments
end

---@type ScipIndexer
local indexer = {
        args = args,

        command = 'scip-java',

        filetypes = {
                java = true,
                kotlin = true,
                scala = true,
                sbt = true,
        },

        markers = {
                '.git',
                'build.gradle',
                'build.gradle.kts',
                'build.sbt',
                'gradlew',
                'pom.xml',
                'settings.gradle',
                'settings.gradle.kts',
        },
}

return indexer
