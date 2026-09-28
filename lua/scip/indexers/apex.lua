-- #################################################################
-- /qompassai/lua/scip/indexers/apex.lua
-- Qompass AI Diver SCIP Apex Indexer
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
--
---@source https://github.com/octoberswimmer/scip-apex
--
-- Community (third-party, not Salesforce-official) SCIP indexer for Apex.
-- Like every other indexer in this directory it degrades gracefully: the
-- registry skips it with an "is not executable" notice when the
-- `scip-apex` binary is absent, so nothing errors on machines without it.

local factory = require('scip.indexers.factory')

--- Arguments passed to scip-apex.
---
--- `index` selects SCIP indexing mode.
--- `.` indexes the project rooted at the cwd selected by the SCIP framework.
---@type string[]
local args = {
    'index',
    '.',
}

return factory.new('apex', {
    args = args,
    command = 'scip-apex',

    filetypes = {
        apex = true,
    },

    markers = {
        '.git',
        '.sf',
        '.sfdx',
        'sfdx-project.json',
    },
})
