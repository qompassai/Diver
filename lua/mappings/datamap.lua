-- /qompassai/Diver/lua/mappings/datamap.lua
-- Qompass AI Diver Data Plugin Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'mappings.datamap'
local M = {}
function M.setup_datamap()
  local map = vim.keymap.set
  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
      local bufnr = ev.buf
      local opts = {
        noremap = true,
        silent = true,
        buffer = bufnr
      }

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
        'n',
        '<leader>nsh',
        vim.lsp.buf.signature_help,
        vim.tbl_extend('force', opts, {
          desc = '[n]vim-lsp [s]how [s]ignature help',
        })
      )
      -- In normal mode, press 'Space' + 's' + 'h' to show signature information for the function under the cursor.

      -- Add workspace folder
      map(
        'n',
        '<leader>naw',
        vim.lsp.buf.add_workspace_folder,
        vim.tbl_extend('force', opts, { desc = '[n]vim-LSP [a]dd [w]orkspace folder' })
      )
      -- In normal mode, press 'Space' + 'w' + 'a' to add the current folder as a workspace.

      -- Remove workspace folder
      map(
        'n',
        '<leader>nrw',
        vim.lsp.buf.remove_workspace_folder,
        vim.tbl_extend('force', opts, { desc = '[n]vim-LSP [r]emove [w]orkspace folder' })
      )
      -- In normal mode, press 'Space' + 'w' + 'r' to remove the current folder workspace.

      -- List workspace folders
      map('n', '<leader>nlw', function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, vim.tbl_extend('force', opts, { desc = '[n]vim-LSP [l]ist [w]orkspace folders' }))
      -- In normal mode, press 'Space' + 'w' + 'l' to list all folders currently in the workspace.

      -- Rename symbol
      map(
        'n',
        '<leader>nrs',
        vim.lsp.buf.rename,
        vim.tbl_extend('force', opts, {
          desc = '[n]vim-LSP [r]ename [s]ymbol',
        })
      )
      -- In normal mode, press 'Space' + 'r' + 's' to rename the symbol under the cursor.

      -- Code action
      map(
        { 'n', 'v' },
        '<leader>nca',
        vim.lsp.buf.code_action,
        vim.tbl_extend('force', opts, { desc = '[n]vim-LSP [c]ode [a]ction' })
      )
      -- In normal and visual modes, press 'Space' + 'c' + 'a' to see available code actions at the current cursor position or selection.

      -- Show references
      map(
        'n',
        'nsr',
        vim.lsp.buf.references,
        vim.tbl_extend('force',
          opts,
          {
            desc = '[n]vim-LSP [s]how [r]eferences',
          })
      )
      -- In normal mode, press 'n' + 's' + 'r' for Nvim-lsp to show references to the symbol under the cursor.
    end,
  })

  local nabla_ok, nabla = pcall(require, 'nabla')
  if nabla_ok then
    map('n', '<leader>mp', function()
      nabla.popup()
    end, {
      desc = 'Preview LaTeX equations'
    })

    map('n', '<leader>mt', function()
      nabla.toggle_virt()
    end, { desc = 'Toggle LaTeX equations' })
  end
end

return M