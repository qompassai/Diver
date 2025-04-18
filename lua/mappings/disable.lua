-- lua/mappings/disable.lua
local M = {}

-- Create the setup function that will be called by your keymaps.lua
M.setup = function()
	-- Your key disabling mappings
	vim.keymap.set("n", "gc", "<Nop>", { noremap = true })
	vim.keymap.set("n", "gcc", "<Nop>", { noremap = true })
	vim.keymap.set("x", "gc", "<Nop>", { noremap = true })
	vim.keymap.set("o", "gc", "<Nop>", { noremap = true })
	-- You can add more disabled mappings here if needed
end

return M
