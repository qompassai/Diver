local M = {}
function M.setup()
	local map = vim.keymap.set
	local bufopts = { noremap = true, silent = true }

	-- Nerd Legend
	-- signature help: Provides information about function signatures while typing.
	-- workspace folder: Refers to a folder that is part of the current coding project.
	-- rename symbol: Change the name of a variable or function throughout the code.
	-- code action: Suggests automated actions to fix or improve code.
	-- references: Shows all places in the code where a symbol (e.g., variable or function) is used.
	-- REPL (Read-Eval-Print Loop): A tool to interactively run code line by line.
	-- Jupyter: An interactive computing environment often used for data analysis and visualization.
	-- kernel: The underlying process that executes code in an interactive environment.
	-- Jupyter kernel: A specific type of kernel used in Jupyter environments to run and interpret code.
	-- -- Magma/Molten: Plugins that allow evaluating specific lines or blocks of code directly in Neovim, similar to Jupyter notebook cells.
	-- Otter output panel: A side panel that displays results or outputs from running code.
	-- Vim-Slime: A plugin that sends code to a terminal, allowing interactive code execution.

	-- Show signature help
	map(
		"n",
		"<leader>sh",
		vim.lsp.buf.signature_help,
		vim.tbl_extend("force", bufopts, { desc = "Show signature help" })
	)
	-- In normal mode, press 'Space' + 's' + 'h' to show signature information for the function under the cursor.

	-- Add workspace folder
	map(
		"n",
		"<leader>wa",
		vim.lsp.buf.add_workspace_folder,
		vim.tbl_extend("force", bufopts, { desc = "Add workspace folder" })
	)
	-- In normal mode, press 'Space' + 'w' + 'a' to add the current folder as a workspace.

	-- Remove workspace folder
	map(
		"n",
		"<leader>wr",
		vim.lsp.buf.remove_workspace_folder,
		vim.tbl_extend("force", bufopts, { desc = "Remove workspace folder" })
	)
	-- In normal mode, press 'Space' + 'w' + 'r' to remove the current folder workspace.

	-- List workspace folders
	map("n", "<leader>lw", function()
		print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
	end, vim.tbl_extend("force", bufopts, { desc = "[l]ist [w]orkspace folders" }))
	-- In normal mode, press 'Space' + 'w' + 'l' to list all folders currently in the workspace.

	-- Rename symbol
	map(
		"n",
		"<leader>ra",
		vim.lsp.buf.rename,
		vim.tbl_extend("force", bufopts, { desc = "Nvim-LSP [r]ename [s]ymbol" })
	)
	-- In normal mode, press 'Space' + 'r' + 'a' to rename the symbol under the cursor.

	-- Code action
	map(
		{ "n", "v" },
		"<leader>Ca",
		vim.lsp.buf.code_action,
		vim.tbl_extend("force", bufopts, { desc = "Nvim-LSP [C]ode [a]ction" })
	)
	-- In normal and visual modes, press 'Space' + 'c' + 'a' to see available code actions at the current cursor position or selection.

	-- Show references
	map("n", "sr", vim.lsp.buf.references, vim.tbl_extend("force", bufopts, { desc = "Nvim-LSP [s]how [r]eferences" }))
	-- In normal mode, press 'g' + 'r' to list all references to the symbol under the cursor.

	-- Toggle Jupyter Lab terminal using toggleterm
	map("n", "<leader>jl", function()
		require("toggleterm.terminal").Terminal:new({ cmd = "jupyter lab", direction = "float" }):toggle()
	end, vim.tbl_extend("force", bufopts, { desc = "start [j]upyter [l]ab terminal" }))
	-- In normal mode, press 'Space' + 'j' + 'l' to start Jupyter lab via Toggleterm plugin.

	-- Iron.nvim REPL mappings
	map(
		"n",
		"<leader>jr",
		"<cmd>IronRepl<CR>",
		vim.tbl_extend("force", bufopts, { desc = "Iron [j]upyter [r]epl ipython" })
	)
	-- In normal mode, press 'Space' + 'j' + 'r' + Open an IPython REPL.

	map(
		"n",
		"<leader>jc",
		"<cmd>IronReplClear<CR>",
		vim.tbl_extend("force", bufopts, { desc = "Iron [j]upyter [c]lear REPL output" })
	)
	-- In normal mode, press 'Space' + 'j' + 'c' to clear the current REPL output.

	map(
		{ "n", "v" },
		"<leader>js",
		"<cmd>IronReplSend<CR>",
		vim.tbl_extend("force", bufopts, { desc = "Iron [j]upyter [s]end code to REPL" })
	)
	-- In normal mode, press 'Space' + 'j' + 's' to send code to REPL.

	-- Jupynium mappings
	map(
		"n",
		"<leader>js",
		"<cmd>JupyniumStartAndAttach<CR>",
		vim.tbl_extend("force", bufopts, { desc = "Jupynium [j]upyter [k]ernel start" })
	)
	-- Start a Jupyter kernel and attach to it.

	map(
		"n",
		"<leader>ja",
		"<cmd>JupyniumAttachToRunningNotebook<CR>",
		vim.tbl_extend("force", bufopts, { desc = "[j]upyter [a]ttach to running jupyter notebook" })
	)
	-- Attach to a running Jupyter kernel.

	map(
		"n",
		"<leader>ji",
		"<cmd>JupyniumKernelInterrupt<CR>",
		vim.tbl_extend("force", bufopts, { desc = "Jupynium [j]upyter [i]nterrupt kernel" })
	)
	-- Interrupt the current Jupyter kernel.

	-- Molten.nvim mappings
	map(
		"n",
		"<leader>je",
		":MoltenInit<CR>",
		vim.tbl_extend("force", bufopts, { desc = "Molten [j]upyter [e]nvironment start" })
	)
	-- Initialize Molten environment.

	map(
		"n",
		"<leader>jr",
		":MoltenReevaluateCell<CR>",
		vim.tbl_extend("force", bufopts, { desc = "Molten [j]upyter [r]eexecute cell" })
	)
	-- Reevaluate the current cell with Molten.

	map(
		"v",
		"<leader>jv",
		":MoltenEvaluateVisual<CR>",
		vim.tbl_extend("force", bufopts, { desc = "Molten [j]upyter evaluate [v]isual" })
	)
	-- Evaluate the selected visual code with Molten.

	-- Otter.nvim output panel
	map(
		"n",
		"<leader>top",
		"<cmd>OtterToggleOutputPanel<CR>",
		vim.tbl_extend("force", bufopts, { desc = "Otter [j]upter [o]utput toggle panel" })
	)
	-- Toggle the Otter output panel.

	-- Vim-Slime terminal mappings
	map(
		"n",
		"<leader>jt",
		":lua vim.fn['slime#mark_terminal']()<CR>",
		vim.tbl_extend("force", bufopts, { desc = "Slime [j]upyter [t]erminal mark" })
	)
	-- Mark the terminal for Slime.

	map(
		"n",
		"<leader>js",
		":lua vim.fn['slime#set_terminal']()<CR>",
		vim.tbl_extend("force", bufopts, { desc = "Slime [j]upyter [s]et terminal" })
	)
	-- Set the terminal for Slime.
end
return M
