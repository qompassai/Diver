local aimap = {}

local function setup_parrot_mappings()
    local map = vim.keymap.set
    local opts = { noremap = true, silent = true }

    -- Parrot Open a new chat
    map("n", "<C-g>c", ":PrtChatNew<CR>", vim.tbl_extend("force", opts, { desc = "[p]arrot [c]hat" }))
    -- In normal mode, press 'Ctrl' + 'g' + 'c' to open a new chat.

    -- Parrot Toggle Popup Chat
    map("n", "<C-g>t", ":PrtChatToggle<CR>", vim.tbl_extend("force", opts, { desc = "Parrot Toggle Popup Chat" }))
    -- In normal mode, press 'Ctrl' + 'g' + 't' to toggle the popup chat.

    -- Parrot Chat Finder
    map("n", "<C-g>f", ":PrtChatFinder<CR>", vim.tbl_extend("force", opts, { desc = "Parrot Chat Finder" }))
    -- In normal mode, press 'Ctrl' + 'g' + 'f' to open the chat finder.

    -- Parrot Trigger the API to generate a response
    map("n", "<C-g><C-g>", ":PrtChatRespond<CR>", opts)
    -- In normal mode, press 'Ctrl' + 'g' + 'g' to trigger the API to generate a response.

    -- Parrot Stop the current text generation
    map("n", "<C-g>s", ":PrtStop<CR>", opts)
    -- In normal mode, press 'Ctrl' + 'g' + 's' to stop the current text generation.

    -- Parrot Delete the current chat file
    map("n", "<C-g>d", ":PrtChatDelete<CR>", opts)
    -- In normal mode, press 'Ctrl' + 'g' + 'd' to delete the current chat file.

    -- Parrot Select Provider
    map("n", "<C-g>p", "<cmd>PrtProvider<cr>", vim.tbl_extend("force", opts, { desc = "Parrot Select provider" }))
    -- In normal mode, press 'Ctrl' + 'g' + 'p' to select a provider.

    -- Parrot Switch Model
    map("n", "<C-g>m", "<cmd>PrtModel<cr>", vim.tbl_extend("force", opts, { desc = "Parrot Switch model" }))
    -- In normal mode, press 'Ctrl' + 'g' + 'm' to switch the model.

    -- Parrot Print plugin config
    map("n", "<C-g>i", ":PrtInfo<CR>", vim.tbl_extend("force", opts, { desc = "Parrot Print plugin config" }))
    -- In normal mode, press 'Ctrl' + 'g' + 'i' to print the plugin config.

    -- Parrot Edit local context file
    map("n", "<C-g>e", ":PrtContext<CR>", vim.tbl_extend("force", opts, { desc = "Parrot Edit local context file" }))
    -- In normal mode, press 'Ctrl' + 'g' + 'e' to edit the local context file.

    -- Parrot Rewrites the visual selection
    map("v", "<C-g>r", ":PrtRewrite<CR>", vim.tbl_extend("force", opts, { desc = "Parrot Rewrite selection" }))
    -- In visual mode, press 'Ctrl' + 'g' + 'r' to rewrite the visual selection based on a prompt.

    -- Parrot Append text to selection
    map("v", "<C-g>a", ":PrtAppend<CR>", vim.tbl_extend("force", opts, { desc = "Parrot Append to selection" }))
    -- In visual mode, press 'Ctrl' + 'g' + 'a' to append text to the visual selection.

    -- Parrot Prepend text to selection
    map("v", "<C-g>p", ":PrtPrepend<CR>", vim.tbl_extend("force", opts, { desc = "Parrot Prepend to selection" }))
    -- In visual mode, press 'Ctrl' + 'g' + 'p' to prepend text to the visual selection.

    -- Parrot Repeat last action
    map("n", "<C-g>r", ":PrtRetry<CR>", vim.tbl_extend("force", opts, { desc = "Parrot Repeat last action" }))
    -- In normal mode, press 'Ctrl' + 'g' + 'r' to repeat the last rewrite/append/prepend.
end

local function setup_dbee_mappings()
    local map = vim.keymap.set
    local opts = { noremap = true, silent = true }

    -- Function to handle errors if there's no current DBee context
    local function safe_dbee_store(data_type, store_type, args)
        local status, err = pcall(function()
            require("dbee").store(data_type, store_type, args)
        end)
        if not status then
            vim.notify("DBee: No active results to store. Please run a query first.", vim.log.levels.ERROR)
        end
    end

    -- dbee mappings
    -- (all previous Parrot mappings you have already written)

    -- Dbee Store results as CSV in current buffer
    map("n", "<C-d>c", function()
        safe_dbee_store("csv", "buffer", { extra_arg = 0 })
    end, vim.tbl_extend("force", opts, { desc = "[D]bee Store CSV in [c]urrent buffer" }))
    -- In normal mode, press 'Ctrl' + 'd' + 'c' to store results as CSV in the current buffer.

    -- Dbee Store results as JSON to file
    map("n", "<C-d>j", function()
        safe_dbee_store("json", "file", { from = 2, to = 7, extra_arg = "path/to/file.json" })
    end, vim.tbl_extend("force", opts, { desc = "[D]bee Store JSON to [j]son file" }))
    -- In normal mode, press 'Ctrl' + 'd' + 'j' to store results as JSON to a file.

    -- Dbee Yank results as table
    map("n", "<C-d>y", function()
        safe_dbee_store("table", "yank", { from = 0, to = 1 })
    end, vim.tbl_extend("force", opts, { desc = "[D]bee [y]ank results as table" }))
    -- In normal mode, press 'Ctrl' + 'd' + 'y' to yank results as a table.

    -- Dbee Yank last 2 rows as CSV
    map("n", "<C-d>r", function()
        safe_dbee_store("csv", "yank", { from = -3, to = -1 })
    end, vim.tbl_extend("force", opts, { desc = "[D]bee yank [r]ows as CSV" }))
    -- In normal mode, press 'Ctrl' + 'd' + 'r' to yank the last 2 rows as CSV.
end

vim.api.nvim_set_keymap('n', '<C-d>q', ":[D]bee query<CR>", { noremap = true, silent = true })

aimap.setup_parrot_mappings = setup_parrot_mappings
aimap.setup_dbee_mappings = setup_dbee_mappings
setup_parrot_mappings()
setup_dbee_mappings()

return aimap
