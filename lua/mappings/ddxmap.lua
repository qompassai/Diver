-- /qompassai/Diver/lua/mappings/ddxmap.lua
-- Qompass AI Diver Diag/debug (ddx) Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'mappings.ddxmap'
local M = {}
function M.setup_ddxmap()
  local map = vim.keymap.set
  map('n', '<leader>S', function()
      require('tests.selfcheck').run()
    end,
    {
      desc = 'Run Neovim config selfcheck'
    })
  vim.api.nvim_create_autocmd('LspAttach',
    {
      callback = function(ev)
        local bufnr = ev.buf
        local opts = {
          noremap = true,
          silent = true,
          buffer = bufnr,
        }
        -- ======================
        -- Nerd Legend --
        -- ======================
        -- Breakpoint: Pause the execution of the code at a specified line.
        -- Continue: Resume the execution of a paused debugging session.
        -- DAP REPL: A console to interact with the debugger, similar to an interactive shell.
        -- Diagnostics: Messages that provide information about issues in the code.
        -- In-file: Refers to actions that apply only to the current file or buffer.
        -- LSP: Language Server Protocol, provides editor features like code completion, diagnostics, etc.
        -- Location List: A window showing errors or search results specific to the current file.
        -- Quickfix List: A list containing errors or search results across multiple files.
        -- REPL: A tool to interactively run code line by line (Read-Eval-Print Loop).
        -- Step Into: Step into a function or block to see its internal execution.
        -- Step Out: Step out of the current function or block to return to the caller.
        -- Step Over: Step over a line, executing it without going into functions.
        -- Symbol: Elements in your code like functions, variables, or classes.
        -- Toggle: Turn a feature on or off.
        -- Trouble: A plugin for managing diagnostics, errors, and quickfix lists visually.
        -- UI: User Interface, components that visually represent information.
        map('n', '<leader>dl', --- In normal mode, press 'Space' + 'd' + 'l' to toggle virtual lines
          function()
            local cfg = vim.diagnostic.config() or {}
            local lines = cfg.virtual_lines
            if lines == nil then
              lines = false
            end
            local new_state = not lines
            vim.diagnostic.config({
              virtual_lines = new_state,
              virtual_text = not new_state,
            })
            local msg = 'Diagnostic virtual_lines: ' .. (new_state and 'enabled' or 'disabled')
            vim.api.nvim_echo({
                {
                  msg,
                  'None'
                }
              },
              false,
              {})
          end, vim.tbl_extend('force', opts,
            {
              desc = 'Toggle diagnostic virtual_lines',
            }))

        map('n', '<leader>dq', --- In normal mode, press 'Space' + 'd' + 'q' to show diagnostics for the entire project
          vim.diagnostic.setqflist,
          {
            desc = 'Show project diagnostics',
          })

        map('n', '<leader>xd', --- In normal mode, press 'Space' + 'x' + 'd' to toggle the Trouble diagnostics window
          '<cmd>Trouble diagnostics toggle<cr>',
          {
            desc = 'Toggle Diagnostics',
          })
        map('n', '<leader>xb', --- In normal mode, press 'Space' + 'x' + 'b' to toggle Trouble diagnostics for current buffer
          '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
          {
            desc = 'Buffer Diagnostics',
          })
        map('n', '<leader>xs', --- In normal mode, press 'Space' + 'x' + 's' to toggle symbols window
          '<cmd>Trouble symbols toggle focus=false<cr>',
          {
            desc = 'Document Symbols',
          })
        map('n', '<leader>xw', --- In normal mode, press 'Space' + 'x' + 'w' for right-aligned LSP references
          '<cmd>Trouble lsp toggle focus=false win.position=right<cr>',
          {
            desc = 'LSP References',
          })
        map('n', '<leader>xl', --- In normal mode, press 'Space' + 'x' + 'l' to toggle location list
          '<cmd>Trouble loclist toggle<cr>',
          {
            desc = 'Location List'
          })
        map('n', '<leader>xq', --- In normal mode, press 'Space' + 'x' + 'q' to toggle quickfix list
          '<cmd>Trouble qflist toggle<cr>',
          {
            desc = 'Quickfix List'
          })
        map('n', '<leader>xt', --- In normal mode, press 'Space' + 'x' + 't' to toggle any active Trouble window
          '<cmd>Trouble toggle<cr>',
          {
            desc = 'Toggle Trouble'
          })
        map('n', '<leader>ds', -- Press <Space> d s to start or continue debugging
          '<cmd>lua require\'dap\'.continue()<CR>',
          {
            desc = 'Start/Continue Debug'
          })
        map('n', '<leader>db', -- Press <Space> d b to toggle breakpoint
          '<cmd>lua require\'dap\'.toggle_breakpoint()<CR>',
          {
            desc = 'Toggle Breakpoint'
          })
        map('n', '<leader>dS', -- Press <Space> d S to step over
          '<cmd>lua require\'dap\'.step_over()<CR>',
          {
            desc = 'Step Over'
          })
        map('n', '<leader>di', -- Press <Space> d i to step into
          '<cmd>lua require\'dap\'.step_into()<CR>',
          {
            desc = 'Step Into'
          })
        map('n', '<leader>do', --- Press <Space> d o to step out
          '<cmd>lua require\'dap\'.step_out()<CR>',
          {
            desc = 'Step Out',
          })
        map('n', '<leader>dr', --- Press <Space> d r to toggle the debug REPL
          "<cmd>lua require'dap'.repl.toggle()<CR>",
          {
            desc = 'Toggle REPL',
          })
        map('n', '<leader>du', --- In normal mode, Press <Space> d u to toggle the DAP UI

          "<cmd>lua require'dapui'.toggle()<CR>",
          {
            desc = 'Toggle DAP UI',
          })
        map('n', '<leader>da', function() --- Press <Space> d a to choose and activate a debug adapter
            vim.ui.select({
                'python',
                'cpp',
                'rust',
                'rust'
              },
              {
                prompt = 'Select debug adapter:',
                format_item = function(item)
                  return ' ' .. item:upper()
                end,
              }, function(choice)
                if choice then
                  require('dap').adapters[choice]()
                end
              end)
          end,
          {
            desc = 'Select Debug Adapter',
          })
        map('n', '<leader>dv', function() --- Press <Space> d v to enable verbose debug logging
          require('dap').set_log_level('DEBUG')
          vim.api.nvim_echo({
              {
                'Debug verbosity increased',
                'None'
              }
            },
            false,
            {})
        end, {
          desc = 'Verbose Debug Mode',
        })
      end,
    })
end

return M