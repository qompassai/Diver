local map = vim.keymap.set

-- Jupyter Notebook Mappings
map("n", "<leader>jc", "<cmd>JupyterConnect<CR>", { desc = "Connect to Jupyter kernel" })
map("n", "<leader>jr", "<cmd>JupyterRunCell<CR>", { desc = "Run current Jupyter cell" })
map("n", "<leader>ja", "<cmd>JupyterRunAll<CR>", { desc = "Run all Jupyter cells" })

return {}

