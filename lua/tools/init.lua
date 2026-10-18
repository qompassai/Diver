-- /qompassai/Diver/lua/tools/init.lua
-- Qompass AI Diver Tools Init
local M = {}

M.video = require('tools.video')

---Wire the tools suites. Called once from the top-level init.lua.
function M.setup()
    M.video.setup()
end

return M
