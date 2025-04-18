-- config/keymaps.lua
local M = {}

M.setup = function()
	local mappings = safe_require("mappings")
	if mappings then
		mappings.setup()
	end
end

return M
