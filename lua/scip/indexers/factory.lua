-- #################################################################
-- /qompassai/lua/scip/indexers/factory.lua
-- Qompass AI SCIP Indexer Factory
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
---Shared constructor for SCIP indexer definitions.
---
---Plain words: every language file under `scip/indexers/` is a plain data
---table shaped like `ScipIndexer`. This constructor checks that shape once,
---at require time, so a malformed definition fails fast naming the indexer
---instead of surfacing later as a confusing indexing failure.
---@module 'scip.indexers.factory'

local indexer = {}

---Validate a `ScipIndexer` definition and return it unchanged.
---
---Shape errors are programmer errors in shipped definitions, so they throw
---with the indexer name. (External input via `registry.register` is
---validated separately and returns `nil, err`.)
---
---@param name string Indexer name, used in error messages.
---@param spec ScipIndexer Indexer definition table.
---@return ScipIndexer spec The validated definition, unchanged.
function indexer.new(name, spec)
    assert(type(name) == 'string', 'scip indexer name must be a string')
    assert(name ~= '', 'scip indexer name must not be empty')
    assert(type(spec) == 'table', "scip indexer '" .. name .. "' must be a table")
    assert(
        type(spec.command) == 'string' or type(spec.command) == 'function',
        "scip indexer '" .. name .. "': command must be a string or function"
    )
    assert(
        type(spec.args) == 'table' or type(spec.args) == 'function',
        "scip indexer '" .. name .. "': args must be a table or function"
    )
    assert(
        type(spec.filetypes) == 'table',
        "scip indexer '" .. name .. "': filetypes must be a table"
    )
    assert(
        type(spec.markers) == 'table',
        "scip indexer '" .. name .. "': markers must be a table"
    )
    assert(
        spec.enabled == nil or type(spec.enabled) == 'boolean',
        "scip indexer '" .. name .. "': enabled must be a boolean when present"
    )

    return spec
end

return indexer
