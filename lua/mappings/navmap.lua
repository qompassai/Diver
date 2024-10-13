-- navmap.lua

local navmap = {}

local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-------------- | Oil Mappings |---------------------

-- Open oil.nvim
map('n', '<leader>o', ':Oil<CR>', opts)
-- <leader>o: Open Oil file explorer in the current directory.

-- Go up a directory in oil.nvim
map('n', '<leader>u', ':Oil -<CR>', opts)
-- <leader>u: Move up a directory in Oil.

-- Custom command to open a specific directory (e.g., home directory)
map('n', '<leader>oh', ':Oil ~/ <CR>', opts)
-- <leader>oh: Open Oil in the home directory.

-- Preview a file (similar to pressing 'p' in netrw)
map('n', '<leader>p', ':Oil preview<CR>', opts)
-- <leader>p: Preview a file in Oil.

-- Close oil.nvim and return to the buffer
map('n', '<leader>oc', ':Oil close<CR>', opts)
-- <leader>oc: Close the Oil buffer.

-------------- | Treesitter Mappings| ---------------------

-- Incremental Selection
map('n', '<leader>si', ':TSNodeIncremental<CR>', opts)
-- <leader>si: Start or expand the selection to the next syntax node incrementally.

map('n', '<leader>sd', ':TSNodeDecremental<CR>', opts)
-- <leader>sd: Shrink the current selection to the previous syntax node.

map('n', '<leader>ss', ':TSScopeIncremental<CR>', opts)
-- <leader>ss: Expand the current selection to include the next syntax scope (e.g., a block or function).

-- Text Objects
map('o', 'af', '<cmd>lua require"nvim-treesitter.textobjects.select".select_textobject("@function.outer")<CR>', opts)
-- af: Select the entire function, including its definition and body.

map('o', 'if', '<cmd>lua require"nvim-treesitter.textobjects.select".select_textobject("@function.inner")<CR>', opts)
-- if: Select only the body of the function (excluding the definition).

map('o', 'ac', '<cmd>lua require"nvim-treesitter.textobjects.select".select_textobject("@class.outer")<CR>', opts)
-- ac: Select the entire class, including the class definition and its body.

map('o', 'ic', '<cmd>lua require"nvim-treesitter.textobjects.select".select_textobject("@class.inner")<CR>', opts)
-- ic: Select only the body of the class (excluding the class definition).

-- Navigation
map('n', '<leader>nf', ':TSTextobjectGotoNextStart @function.outer<CR>', opts)
-- <leader>nf: Navigate to the start of the next function.

map('n', '<leader>pf', ':TSTextobjectGotoPreviousStart @function.outer<CR>', opts)
-- <leader>pf: Navigate to the start of the previous function.

-- Highlight Toggle
map('n', '<leader>th', ':TSBufToggle highlight<CR>', opts)
-- <leader>th: Toggle Treesitter-based syntax highlighting for the current buffer.

-- Playground
map('n', '<leader>tp', ':TSPlaygroundToggle<CR>', opts)
-- <leader>tp: Open or close the Treesitter Playground, which helps visualize the syntax tree and captures in the current buffer.

-- Query Editor
map('n', '<leader>tq', ':TSHighlightCapturesUnderCursor<CR>', opts)
-- <leader>tq: Show the Treesitter capture groups under the cursor. Useful for debugging highlighting and understanding syntax nodes.

-- Swap Parameters
map('n', '<leader>sn', ':TSTextobjectSwapNext @parameter.inner<CR>', opts)
-- <leader>sn: Swap the current parameter with the next one in function arguments.

map('n', '<leader>sp', ':TSTextobjectSwapPrevious @parameter.inner<CR>', opts)
-- <leader>sp: Swap the current parameter with the previous one in function arguments.

-- Folding
map('n', '<leader>cf', ':TSFoldToggle<CR>', opts)
-- <leader>cf: Toggle folding based on the Treesitter syntax nodes, allowing you to fold or unfold code blocks.

return navmap

