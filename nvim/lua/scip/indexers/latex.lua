-- #################################################################
-- /qompassai/lua/scip/indexers/latex.lua
-- Qompass AI SCIP LaTeX Indexer
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

---Native SCIP indexer definition for LaTeX.
---
---No verified standard LaTeX-to-SCIP indexer is currently available.
---Existing LaTeX indexing utilities generally generate document indexes,
---rather than SCIP code-intelligence indexes.
---
---This definition is disabled until a compatible `scip-latex` executable is
---installed or implemented.
---@type ScipIndexer
local indexer = {
        args = {
                'index',
                '.',
        },

        command = 'scip-latex',

        enabled = false,

        filetypes = {
                bib = true,
                latex = true,
                plaintex = true,
                tex = true,
        },

        markers = {
                '.git',
                '.latexmkrc',
                'latexmkrc',
                'texmf.cnf',
        },
}

return indexer
