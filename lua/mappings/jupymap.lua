local map = vim.keymap.set

-- Jupyter Notebook Mappings
map("n", "<leader>jc", "<cmd>JupyterConnect<CR>", { desc = "Connect to Jupyter kernel" })
map("n", "<leader>jr", "<cmd>JupyterRunCell<CR>", { desc = "Run current Jupyter cell" })
map("n", "<leader>ja", "<cmd>JupyterRunAll<CR>", { desc = "Run all Jupyter cells" })
map("n", "<leader>jn", "<cmd>JupyterNewCell<CR>", { desc = "Create new cell below" })
map("n", "<leader>jb", "<cmd>JupyterNewCellAbove<CR>", { desc = "Create new cell above" })
map("n", "<leader>jd", "<cmd>JupyterDeleteCell<CR>", { desc = "Delete current cell" })
map("n", "<leader>js", "<cmd>JupyterSplitCell<CR>", { desc = "Split current cell" })
map("n", "<leader>jm", "<cmd>JupyterMergeCellBelow<CR>", { desc = "Merge cell with cell below" })
map("n", "<leader>jt", "<cmd>JupyterToggleCellType<CR>", { desc = "Toggle cell type (code/markdown)" })
map("n", "<leader>jp", "<cmd>JupyterTogglePythonRepl<CR>", { desc = "Toggle Python REPL" })
map("n", "<leader>jv", "<cmd>JupyterViewOutput<CR>", { desc = "View output of last executed cell" })
map("n", "<leader>jh", "<cmd>JupyterCommandHistory<CR>", { desc = "Show Jupyter command history" })
map("n", "<leader>ji", "<cmd>JupyterInsertImports<CR>", { desc = "Insert cell with common Python imports" })
map("n", "<leader>jf", "<cmd>JupyterFormatNotebook<CR>", { desc = "Format entire notebook" })

-- Jupyter Notebook Mappings
map("n", "<leader>jx", ":Jupytext<CR>", { desc = "Convert between notebook and script" })

-- Jupyter connection and file operations
map("n", "<leader>jc", ":JupyterConnect<CR>", { desc = "Connect to Jupyter kernel" })
map("n", "<leader>jr", ":JupyterRunFile<CR>", { desc = "Run current file in Jupyter" })
map("n", "<leader>ji", ":PythonImportThisFile<CR>", { desc = "Import current file in Jupyter" })
map("n", "<leader>jd", ":JupyterCd %:p:h<CR>", { desc = "Change Jupyter working directory to current file" })

-- Cell operations
map("n", "<leader>jn", ":JupyterNewCell<CR>", { desc = "Create new cell below" })
map("n", "<leader>jb", ":JupyterNewCellAbove<CR>", { desc = "Create new cell above" })
map("n", "<leader>jD", ":JupyterDeleteCell<CR>", { desc = "Delete current cell" })
map("n", "<leader>js", ":JupyterSplitCell<CR>", { desc = "Split current cell" })
map("n", "<leader>jm", ":JupyterMergeCellBelow<CR>", { desc = "Merge cell with cell below" })
map("n", "<leader>jt", ":JupyterToggleCellType<CR>", { desc = "Toggle cell type (code/markdown)" })

-- Cell execution
map("n", "<leader>je", ":JupyterSendCell<CR>", { desc = "Execute current cell" })
map("n", "<leader>jE", ":JupyterCellExecuteCellJump<CR>", { desc = "Execute current cell and jump to next" })
map("n", "<leader>ja", ":JupyterRunAllCells<CR>", { desc = "Run all cells" })
map("n", "<leader>jA", ":JupyterRunAllCellsAbove<CR>", { desc = "Run all cells above" })
map("n", "<leader>jB", ":JupyterRunAllhellsBelow<CR>", { desc = "Run all cells below" })

-- Output and REPL
map("n", "<leader>jp", ":JupyterTogglePythonRepl<CR>", { desc = "Toggle Python REPL" })
map("n", "<leader>jv", ":JupyterViewOutput<CR>", { desc = "View output of last executed cell" })
map("n", "<leader>jh", ":JupyterCommandHistory<CR>", { desc = "Show Jupyter command history" })
map("n", "<leader>jC", ":JupyterCellClear<CR>", { desc = "Clear current cell output" })

-- Navigation
map("n", "[c", ":JupyterCellPrev<CR>", { desc = "Go to previous cell" })
map("n", "]c", ":JupyterCellNext<CR>", { desc = "Go to next cell" })

-- ToggleTerm for Jupyter Lab
map(
  "n",
  "<leader>jl",
  "<cmd>ToggleTerm direction=float<CR>jupyter lab<CR>",
  { desc = "Open Jupyter Lab in floating terminal" }
)

-- Additional operations
map("n", "<leader>jf", ":JupyterFormatNotebook<CR>", { desc = "Format entire notebook" })
map("n", "<leader>jU", ":JupyterUpdateShell<CR>", { desc = "Update Jupyter shell" })


return {}

