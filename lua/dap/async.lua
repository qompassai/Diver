-- #################################################################
-- /qompassai/lua/dap/async.lua
-- Qompass AI Async
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
local M = {}

--- Run `fn`, guaranteeing it executes inside a coroutine.
---
--- If the caller is already in a coroutine, `fn` runs inline; otherwise it
--- is wrapped in a fresh coroutine so `coroutine.yield` works inside it.
--- Errors are reported via `dap.utils.notify` with a traceback instead of
--- propagating: async event handlers must never take down the dispatcher.
--- Behavior is unchanged from upstream nvim-dap; only the contract is now
--- written down.
---@param fn fun(): nil
function M.run(fn)
    local co, is_main = coroutine.running()
    if co and not is_main then
        fn()
    else
        coroutine.wrap(function()
            xpcall(fn, function(err)
                local msg = debug.traceback(err, 2)
                require('dap.utils').notify(msg, vim.log.levels.ERROR)
            end)
        end)()
    end
end

return M
