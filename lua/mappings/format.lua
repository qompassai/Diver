local map = vim.keymap.set
local automatic_setup = require("mappings.automatic_setup")

-- Ensure that the formatter is registered if it isn't already
automatic_setup("stylua", { "formatting" })

-- Format mapping for Lua
map("n", "<leader>fm", function()
  require("conform").format { lsp_fallback = true }
end, { desc = "format files" })

return {}

