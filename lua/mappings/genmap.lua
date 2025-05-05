-- genmap.lua - Modular key mappings configuration for Neovim
local M = {}

function M.setup()
  local map = vim.keymap.set
  local opts = { noremap = true, silent = true }

  -- Neovim operates in four "modes": \27[1mNormal\27[0m, \27[1mCommand*\27[0m, \27[1mInsert\27[0m, and \27[1mVisual\27[0m.

  -- \27[1mNormal Mode\27[0m: The default mode, used to navigate around your data without changing it directly.
  -- \27[1mInsert Mode\27[0m: Allows you to interact with the data in a detailed way, such as typing and editing text.
  -- \27[1mVisual Mode\27[0m: Allows you to select parts of the text interactively, like highlighting with a mouse, so you can then manipulate the selection (e.g., copy, delete).
  -- \27[1mCommand Mode*\27[0m: Used to execute specific commands from normal mode, such as saving a file, editing with AI tools, or running database queries. or running database queries.

  ----------------- Insert Mode Mappings -----------------------

  -- Move to the beginning of the line while in insert mode
  map("i", "<C-b>", "<ESC>^i", vim.tbl_extend("force", opts, { desc = "Move to the beginning of the line" }))

  -- Move to the end of the line while in insert mode
  map("i", "<C-e>", "<End>", vim.tbl_extend("force", opts, { desc = "Move to the end of the line" }))

  -- Move left by one character while in insert mode
  map("i", "<C-h>", "<Left>", vim.tbl_extend("force", opts, { desc = "Move left by one character" }))

  -- Move right by one character while in insert mode
  map("i", "<C-l>", "<Right>", vim.tbl_extend("force", opts, { desc = "Move right by one character" }))

  -- Move down by one line while in insert mode
  map("i", "<C-j>", "<Down>", vim.tbl_extend("force", opts, { desc = "Move down by one line" }))

  -- Move up by one line while in insert mode
  map("i", "<C-k>", "<Up>", vim.tbl_extend("force", opts, { desc = "Move up by one line" }))

  ----------------- Normal Mode Mappings -----------------------

  -- Clear search highlights by pressing Escape in normal mode
  map("n", "<Esc>", "<cmd>noh<CR>", vim.tbl_extend("force", opts, { desc = "Clear search highlights" }))

  -- Switch to the window on the left in normal mode
  map("n", "<C-h>", "<C-w>h", vim.tbl_extend("force", opts, { desc = "Switch to the window on the left" }))

  -- Switch to the window on the right in normal mode
  map("n", "<C-l>", "<C-w>l", vim.tbl_extend("force", opts, { desc = "Switch to the window on the right" }))

  -- Switch to the window below in normal mode
  map("n", "<C-j>", "<C-w>j", vim.tbl_extend("force", opts, { desc = "Switch to the window below" }))

  -- Switch to the window above in normal mode
  map("n", "<C-k>", "<C-w>k", vim.tbl_extend("force", opts, { desc = "Switch to the window above" }))

  -- Save the current file by pressing Control + s in normal mode
  map("n", "<C-s>", "<cmd>w<CR>", vim.tbl_extend("force", opts, { desc = "Save the current file" }))

  -- Copy the entire file to the system clipboard in normal mode
  map("n", "<C-c>", "<cmd>%y+<CR>", vim.tbl_extend("force", opts, { desc = "Copy the entire file to the clipboard" }))

  vim.keymap.set("n", "<leader>f", function()
    if #vim.lsp.get_clients({ bufnr = 0 }) > 0 then
      vim.lsp.buf.format({ async = true })
    else
      vim.notify("No active LSP client with formatting support.", vim.log.levels.WARN)
    end
  end, { desc = "Global Format (LSP if available)", noremap = true, silent = true })
end
return M
