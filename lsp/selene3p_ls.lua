-- /qompassai/Diver/lsp/selene3p_ls.lua
-- Qompass AI Selene 3rd Party LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/antonk52/lua-3p-language-servers
--pnpm add -g lua-3p-language-servers@latest
---@type vim.lsp.Config
return {
      cmd = { ---@type string[]
        'selene-3p-language-server',
      },
      filetypes = { ---@type string[]
        'lua',
      },
      root_markers = { ---@type string[]
        'selene.toml',
      },
    },
    vim.api.nvim_create_user_command('SeleneCheck', function()
      vim.cmd('write') ---@type string[]
      vim.fn.jobstart({ 'selene', vim.api.nvim_buf_get_name(0) }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data) ---@param data string[]|nil
          if data then
            print(table.concat(data, '\n'))
          end
        end,
        on_stderr = function(_, data) ---@param data string[]|nil
          if data then
            print(table.concat(data, '\n'))
          end
        end,
      })
    end, {})