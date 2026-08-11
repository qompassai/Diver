-- #################################################################
-- /qompassai/lua/scip/indexers/python.lua
-- Qompass AI SCIP Python Indexer
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

---Arguments passed to scip-python.
---
---`index` selects SCIP indexing mode.
---`.` indexes the project rooted at the cwd selected by the SCIP framework.
---@type string[]
local args = {
        'index',
        '.',
}

---@type ScipIndexer
local indexer = {
        args = args,

        command = 'scip-python',

        filetypes = {
                python = true,
        },

        markers = {
                '.git',
                'Pipfile',
                'poetry.lock',
                'pyproject.toml',
                'pyrightconfig.json',
                'requirements.txt',
                'setup.cfg',
                'setup.py',
                'uv.lock',
        },
}

return indexer
