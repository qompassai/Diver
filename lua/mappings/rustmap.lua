 --/Diver/lua/mappings/rustmap.lua
local M = {}

function M.setup_rustmap()
  local group = vim.api.nvim_create_augroup("RustMappings", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "rust", "toml" },
    group = group,
    callback = function(args)
      local bufnr = args.buf
      local filetype = vim.bo[bufnr].filetype
      local map = vim.keymap.set
      local opts = { noremap = true, silent = true, buffer = bufnr }

      if filetype == "toml" then
        local ok, crates = pcall(require, "crates")
        if ok then
          require("which-key").register({
            ["<leader>c"] = { name = "+crates" },
          }, { buffer = bufnr })

          map("n", "<leader>cd", crates.open_documentation, vim.tbl_extend("force", opts, { desc = "Open documentation" }))
          map("n", "<leader>cf", crates.show_features, vim.tbl_extend("force", opts, { desc = "Show features" }))
          map("n", "<leader>ci", crates.open_crates_io, vim.tbl_extend("force", opts, { desc = "Open crates.io" }))
          map("n", "<leader>ch", crates.open_homepage, vim.tbl_extend("force", opts, { desc = "Open homepage" }))
          map("n", "<leader>cr", crates.reload, vim.tbl_extend("force", opts, { desc = "Reload data" }))
          map("n", "<leader>ct", crates.toggle, vim.tbl_extend("force", opts, { desc = "Toggle window" }))
          map("n", "<leader>cu", crates.update_crate, vim.tbl_extend("force", opts, { desc = "Update crate" }))
          map("n", "<leader>cU", crates.update_all_crates, vim.tbl_extend("force", opts, { desc = "Update all" }))
          map("n", "<leader>cA", crates.upgrade_crate, vim.tbl_extend("force", opts, { desc = "Upgrade crate" }))
          map("n", "<leader>cR", crates.upgrade_all_crates, vim.tbl_extend("force", opts, { desc = "Upgrade all" }))
        end
      end

      if filetype == "rust" then
        require("which-key").register({
          ["<leader>r"] = { name = "+rust" },
          ["<leader>t"] = { name = "+toggle" },
        }, { buffer = bufnr })

        map("n", "<space>ca", vim.lsp.buf.code_action, { desc = "Code actions", buffer = bufnr })
        map("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration", buffer = bufnr })
        map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition", buffer = bufnr })
        map("n", "gi", vim.lsp.buf.implementation, { desc = "Go to implementation", buffer = bufnr })
        map("n", "gr", vim.lsp.buf.references, { desc = "Show references", buffer = bufnr })
        map("n", "sh", vim.lsp.buf.hover, { desc = "Hover info", buffer = bufnr })
        map("n", "<space>rn", vim.lsp.buf.rename, { desc = "Rename symbol", buffer = bufnr })
        map("n", "<C-k>", vim.lsp.buf.signature_help, { desc = "Signature help", buffer = bufnr })
        map("n", "<space>D", vim.lsp.buf.type_definition, { desc = "Type definition", buffer = bufnr })

        map("n", "<leader>rt", "<cmd>RustExpandMacro<CR>", { desc = "Expand macro", buffer = bufnr })
        map("n", "<leader>rp", "<cmd>RustParentModule<CR>", { desc = "Parent module", buffer = bufnr })
        map("n", "<leader>rc", "<cmd>RustOpenCargo<CR>", { desc = "Open Cargo.toml", buffer = bufnr })
        map("n", "<leader>rd", "<cmd>RustDebuggables<CR>", { desc = "Debuggables", buffer = bufnr })
        map("n", "<leader>rr", "<cmd>RustRunnables<CR>", { desc = "Runnables", buffer = bufnr })

        map("n", "<leader>tc", function()
        end, { desc = "Toggle comment continuation", buffer = bufnr })
      end
    end
  })
end

return M

