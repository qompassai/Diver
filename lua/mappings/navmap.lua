-- ~/.config/nvim/lua/mappings/navmap.lua
local M = {}
function M.setup_navmap()
    local map = vim.keymap.set
    local opts = {noremap = true, silent = true} -- Nerd Translate Legend:
    --
    -- 'Oil': A file manager that lets you interactively edit your directory/file systems
    -- 'Treesitter': A parsing system that provides detailed information about the structure of source code
    -- 'Directory': A folder on your computer that contains files and other folders
    -- 'Buffer': A temporary space in memory where a file is loaded for editing. TLDR buffer = any file, terminal, or UI feature.
    -- 'File Explorer': A tool that shows you the files and folders on your computer
    -- 'Home Directory': The main folder for your user account on the computer
    -- 'Preview': A quick look at a file without fully opening it
    -- 'Selection': The part of text you've highlighted or chosen
    -- 'Function': A block of code that performs a specific task, eg adding up prices of items in a shopping cart.
    -- 'Class': A programming blueprint for creating objects , eg a 'Car' classes are 'color' and 'model', and actions like 'start' and 'stop'.
    -- 'Syntax Highlighting': Coloring different parts of code to make it easier to read
    -- 'Playground': A place to experiment and see how Treesitter understands your code
    -- 'Captures': How Treesitter identifies different parts of your code
    -- 'Parameter': A value that you pass into a function
    -- 'Code Folding': Hiding parts of your code to make it easier to read
    -- General Buffer navigation
    map("n", "<tab>", "<cmd>BufferLineCycleNext<CR>",
        {noremap = true, silent = true, desc = "buffer goto next"})
    map("n", "<S-tab>", "<cmd>BufferLineCyclePrev<CR>",
        {desc = "buffer goto prev"})
    map("n", "<S-tab>", "<cmd>BufferLineCyclePrev<CR>",
        {desc = "buffer goto prev"})
    map("n", "<leader>x", "<cmd>bdelete<CR>", {desc = "buffer delete"})

    -------------- | Oil Mappings |---------------------
    -- Open Oil File Explorer
    map("n", "<leader>oof", ":Oil<CR>",
        vim.tbl_extend("force", opts, {desc = "[o]il [o]pen [f]ile explorer"}))
    -- In normal mode, press 'Space' + 'o' + 'f' to open the Oil file explorer.
    -- Oil Move Up into Parent Directory (like "cd ..")
    map("n", "<leader>omu", ":Oil -<CR>", vim.tbl_extend("force", opts, {
        desc = "Oil Move Up to Parent Directory"
    }))
    -- In normal mode, press 'Space' + 'o' + 'm' +'u' to move up a directory in Oil.
    -- Open Oil in Home Directory
    map("n", "<leader>ooh", ":Oil ~/ <CR>", vim.tbl_extend("force", opts, {
        desc = "[o]il [o]pen in [h]ome Directory"
    }))
    -- In normal mode, press 'Space' + 'o' + 'h' to open Oil in the home directory.
    -- Oil File Preview
    map("n", "<leader>op", ":Oil preview<CR>",
        vim.tbl_extend("force", opts, {desc = "Oil Preview File"}))
    -- In normal mode, press 'Space' + 'o' + 'p' to preview a file with Oil.
    -- Close Oil Buffer
    map("n", "<leader>oc", ":Oil close<CR>",
        vim.tbl_extend("force", opts, {desc = "Oil Close Buffer"}))
    -- In normal mode, press 'Space' + 'o' + 'c' to close the Oil buffer.
    -- Indent Blankline (IBL) Mappings --
    -- Show Indent Context (Replace or Remove the Invalid Call)
    map("n", "<leader>lc", function() require("ibl").refresh(0) end,
        vim.tbl_extend("force", opts, {desc = "IB[l] Refresh Indent Context"}))
    -- Toggle Indent Guides Visibility
    map("n", "<leader>lg", function() require("ibl").toggle() end,
        vim.tbl_extend("force", opts, {desc = "IB[l] toggle indent [g]uides"}))
    -- Toggle Scope Highlighting
    map("n", "<leader>ls",
        function() require("ibl").toggle_scope_highlighting() end,
        vim.tbl_extend("force", opts,
                       {desc = "IB[l] toggle [s]cope highlighting"}))
    -- Refresh Indent Guides
    map("n", "<leader>lr", function() require("ibl").refresh(0) end,
        vim.tbl_extend("force", opts, {desc = "IB[l] [r]efresh Indent Guides"}))
    -- Toggle Indent Blankline Visibility
    map("n", "<leader>li", function()
        local current_value = vim.g.indent_blankline_enabled or false
        vim.g.indent_blankline_enabled = not current_value
        if vim.g.indent_blankline_enabled then
            require("ibl").setup()
            require("ibl").refresh(0)
        else
            require("ibl").setup({indent = {char = ""}})
            require("ibl").refresh(0)
        end
    end, vim.tbl_extend("force", opts,
                        {desc = "IB[l] Toggle Indent Blankline visibility"}))
    -------------- | Treesitter (TS) Mappings | ---------------------
    -- Expand Selection Incrementally (Treesitter)
    map("n", "<leader>TEI", ":TSNodeIncremental<CR>", vim.tbl_extend("force",
                                                                    opts, {
        desc = "TS [E]xpand Selection [I]ncrementally"
    }))
    -- In normal mode, press 'Space' + 'E' + 'T' to expand selection step by step.

    -- Shrink Selection Incrementally (Treesitter)
    map("n", "<leader>TIS", ":TSNodeDecremental<CR>", vim.tbl_extend("force",
                                                                    opts, {
        desc = "TS [I]ncrementally [S]hrink Selection"
    }))
    -- In normal mode, press 'Space' + 'I' + 'S' to shrink selection step by step.
    -- Expand to Next Larger Code Block (Treesitter)
    map("n", "<leader>Tss", ":TSScopeIncremental<CR>",
        vim.tbl_extend("force", opts,
                       {desc = "TS Expand Selection to Next Larger Code Block"}))
    -- In normal mode, press 'Space' + 's' + 's' to expand selection to the next larger code block.
    -- Select Entire Function (Treesitter)
    map("n", "TsF",
        '<cmd>lua require"nvim-treesitter.textobjects.select".select_textobject("@function.outer")<CR>',
        vim.tbl_extend("force", opts, {desc = "TS Select Entire Function"}))
    -- In operator-pending mode, press 'a' + 'f' to select the entire function (including definition and body).
    -- Select Function Body Only (Treesitter)
    map("o", "Tsf",
        '<cmd>lua require"nvim-treesitter.textobjects.select".select_textobject("@function.inner")<CR>',
        vim.tbl_extend("force", opts, {desc = "TS Select Function Body Only"}))
    -- In operator-pending mode, press 'i' + 'f' to select only the body of the function.
    -- Select Entire Class (Treesitter)
    map("n", "TSC",
        '<cmd>lua require"nvim-treesitter.textobjects.select".select_textobject("@class.outer")<CR>',
        vim.tbl_extend("force", opts, {desc = "TS Select Entire Class"}))
    -- In operator-pending mode, press 'a' + 'c' to select the entire class (including definition and body).
    -- Select Class Body Only (Treesitter)
    map("o", "Tsc",
        '<cmd>lua require"nvim-treesitter.textobjects.select".select_textobject("@class.inner")<CR>',
        vim.tbl_extend("force", opts, {desc = "TS Select Class Body Only"}))
    -- In operator-pending mode, press 'T' + 's' + c' to select only the body of the class.

    -- Navigate to Next Function Start (Treesitter)
    map("n", "<leader>Tnf", ":TSGotoNextFunction<CR>", vim.tbl_extend("force",
                                                                     opts, {
        desc = "TS Navigate to Next Function Start"
    }))
    -- In normal mode, press 'Space' + 'T' + 'n' + 'f' to go to the start of the next function.

    -- Navigate to Previous Function Start (Treesitter)
    map("n", "<leader>TpF", ":TSGotoPreviousFunction<CR>", vim.tbl_extend(
            "force", opts, {desc = "TS Navigate to Previous Function Start"}))
    -- In normal mode, press 'Space' + 't' + 'p' to go to the start of the previous function.

    -- Toggle Treesitter Syntax Highlighting
    map("n", "<leader>Tsh", ":TSToggleHighlight<CR>",
        vim.tbl_extend("force", opts, {desc = "TS Toggle Syntax Highlighting"}))
    -- In normal mode, press 'Space' + 't' + 's' to turn syntax highlighting on or off.

    -- Toggle Treesitter Playground
    map("n", "<leader>Tp", ":TSTogglePlayground<CR>",
        vim.tbl_extend("force", opts, {desc = "TS Toggle Playground"}))
    -- In normal mode, press 'Space' + 'T' + 'p' to open or close the Treesitter Playground.

    -- Show Syntax Info Under Cursor (Treesitter Captures)
    map("n", "<leader>Tu", ":TSShowCaptures<CR>", vim.tbl_extend("force", opts,
                                                                 {
        desc = "TS Show Syntax Info Under Cursor"
    }))
    -- In normal mode, press 'Space' + 'T' + 'u' to show syntax information under the cursor.

    -- Swap with Next Parameter (Treesitter)
    map("n", "<leader>Tsn", ":TSSwapNextParameter<CR>",
        vim.tbl_extend("force", opts, {desc = "TS Swap with Next Parameter"}))
    -- In normal mode, press 'Space' + 'T' 's' + 'n' to swap the current parameter with the next one.

    -- Swap with Previous Parameter (Treesitter)
    map("n", "<leader>Tsp", ":TSSwapPreviousParameter<CR>", vim.tbl_extend(
            "force", opts, {desc = "TS Swap with Previous Parameter"}))
    -- In normal mode, press 'Space' + 'T' + 's' + 'p' to swap the current parameter with the previous one.

    -- Toggle Code Folding (Treesitter)
    map("n", "<leader>Tcf", ":TSToggleFold<CR>",
        vim.tbl_extend("force", opts, {desc = "TS Toggle [c]ode Folding"}))
    -- In normal mode, press 'Space' + 'T' + 'c' + 'f' to fold or unfold code blocks.
end
return M
