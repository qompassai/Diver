-- Preserve Neovim's native commenting and editing defaults.
-- SPDX-License-Identifier: Apache-2.0
local M = {}

-- The former gc/gcc <Nop> overrides are deliberately absent. Restart once after
-- migration so anonymous autocmds from the old module cannot disable them again.
function M.setup()
    return true
end

function M.teardown() end
M.setup_disable = M.setup
return M
