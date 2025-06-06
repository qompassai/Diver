local M = {}

local function setup_aimap()
  local map = vim.keymap.set
  local opts = { noremap = true, silent = true }

  -- Rose Open a new chat
  map("n", "<C-g>c", ":RoseChatNew<CR>", vim.tbl_extend("force", opts, { desc = "[r]ose [c]hat" }))
  -- In normal mode, press 'Ctrl' + 'g' + 'c' to open a new chat.

  -- Rose Toggle Popup Chat
  map("n", "<C-g>t", ":RoseChatToggle<CR>", vim.tbl_extend("force", opts, { desc = "[r] Toggle Popup Chat" }))
  -- In normal mode, press 'Ctrl' + 'g' + 't' to toggle the popup chat.

  -- Rose Chat Finder
  map("n", "<C-g>f", ":RoseChatFinder<CR>", vim.tbl_extend("force", opts, { desc = "Rose Chat Finder" }))
  -- In normal mode, press 'Ctrl' + 'g' + 'f' to open the chat finder.

  -- Rose Trigger the API to generate a response
  map("n", "<C-g><C-g>", ":RoseChatRespond<CR>", opts)
  -- In normal mode, press 'Ctrl' + 'g' + 'g' to trigger the API to generate a response.

  -- Rose Stop the current text generation
  map("n", "<C-g>s", ":RoseStop<CR>", opts)
  -- In normal mode, press 'Ctrl' + 'g' + 's' to stop the current text generation.

  -- Rose Delete the current chat file
  map("n", "<C-g>d", ":RoseChatDelete<CR>", opts)
  -- In normal mode, press 'Ctrl' + 'g' + 'd' to delete the current chat file.

  -- Rose Select Provider
  map("n", "<C-g>p", "<cmd>RoseProvider<CR>", vim.tbl_extend("force", opts, { desc = "Rose Select provider" }))
  -- In normal mode, press 'Ctrl' + 'g' + 'p' to select a provider.

  -- Rose Switch Model
  map("n", "<C-g>m", ":RoseModel<CR>", vim.tbl_extend("force", opts, { desc = "Rose Switch model" }))
  -- In normal mode, press 'Ctrl' + 'g' + 'm' to switch the model.

  -- Rose Print plugin config
  map("n", "<C-g>i", ":RoseInfo<CR>", vim.tbl_extend("force", opts, { desc = "Rose Print plugin config" }))
  -- In normal mode, press 'Ctrl' + 'g' + 'i' to print the plugin config.

  -- Rose Edit local context file
  map("n", "<C-g>e", ":RoseContext<CR>", vim.tbl_extend("force", opts, { desc = "Rose Edit local context file" }))
  -- In normal mode, press 'Ctrl' + 'g' + 'e' to edit the local context file.

  -- Rose Rewrites the visual selection
  map("v", "<C-g>r", ":RoseRewrite<CR>", vim.tbl_extend("force", opts, { desc = "Rose Rewrite selection" }))
  -- In visual mode, press 'Ctrl' + 'g' + 'r' to rewrite the visual selection based on a prompt.

  -- Rose Append text to selection
  map("v", "<C-g>a", ":RoseAppend<CR>", vim.tbl_extend("force", opts, { desc = "Rose Append to selection" }))
  -- In visual mode, press 'Ctrl' + 'g' + 'a' to append text to the visual selection.

  -- Rose Prepend text to selection
  map("v", "<C-g>p", ":RosePrepend<CR>", vim.tbl_extend("force", opts, { desc = "Rose Prepend to selection" }))
  -- In visual mode, press 'Ctrl' + 'g' + 'p' to prepend text to the visual selection.

  -- Rose Repeat last action
  map("n", "<C-g>r", ":RoseRetry<CR>", vim.tbl_extend("force", opts, { desc = "Rose Repeat last action" }))
  -- In normal mode, press 'Ctrl' + 'g' + 'r' to repeat the last rewrite/append/prepend.
end

local function setup_dbmap()
  local map = vim.keymap.set
  local opts = { noremap = true, silent = true }

  local function dbstore(data_type, store_type, args)
    local status = pcall(function()
      require("dbee").store(data_type, store_type, args)
    end)
    if not status then
      vim.notify("DBee: No active results to store. Please run a query first.", vim.log.levels.ERROR)
    end
  end

  -- dbee mappings

  -- Dbee Store results as CSV in current buffer
  map("n", "<C-d>c", function()
    dbstore("csv", "buffer", { extra_arg = 0 })
  end, vim.tbl_extend("force", opts, { desc = "[D]bee Store CSV in [c]urrent buffer" }))
  -- In normal mode, press 'Ctrl' + 'd' + 'c' to store results as CSV in the current buffer.

  -- Dbee Store results as JSON to file
  map("n", "<C-d>j", function()
    dbstore("json", "file", { from = 2, to = 7, extra_arg = "path/to/file.json" })
  end, vim.tbl_extend("force", opts, { desc = "[D]bee Store JSON to [j]son file" }))
  -- In normal mode, press 'Ctrl' + 'd' + 'j' to store results as JSON to a file.

  -- Dbee Yank results as table
  map("n", "<C-d>y", function()
    dbstore("table", "yank", { from = 0, to = 1 })
  end, vim.tbl_extend("force", opts, { desc = "[D]bee [y]ank results as table" }))
  -- In normal mode, press 'Ctrl' + 'd' + 'y' to yank results as a table.

  -- Dbee Yank last 2 rows as CSV
  map("n", "<C-d>r", function()
    dbstore("csv", "yank", { from = -3, to = -1 })
  end, vim.tbl_extend("force", opts, { desc = "[D]bee yank [r]ows as CSV" }))
  -- In normal mode, press 'Ctrl' + 'd' + 'r' to yank the last 2 rows as CSV.
end
M.setup = function()
  setup_aimap()
  setup_aimap()

  vim.api.nvim_set_keymap("n", "<C-d>q", ":[D]bee query<CR>", { noremap = true, silent = true })
end
M.setup_aimap = setup_aimap
M.setup_dbee_mappings = setup_dbee_mappings

return M
