-- /qompassai/Diver/lsp/zk_ls.lua
-- Qompass AI Diver ZK LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@param bufnr integer
---@param opts table|nil
---@param action fun(path: string, title: string)
local function zk_list(client, bufnr, opts, action) ---@param client vim.lsp.Client
  opts = vim.tbl_extend('keep', {
      select = {
        'path',
        'title'
      }
    },
    opts or {})
  client:exec_cmd(
    {
      title = 'ZkList',
      command = 'zk.list',
      arguments = {
        vim.api.nvim_buf_get_name(bufnr),
        opts
      },
    },
    {
      bufnr = bufnr
    },
    ---@param err lsp.ResponseError|nil
    function(err, result) ---@param result { path: string, title: string }[]|nil
      if err ~= nil then
        vim.api.nvim_echo({
            {
              'zk.list error\n'
            },
            {
              vim.inspect(err)
            },
          },
          true, {})
        return
      end
      if result == nil then
        return
      end
      vim.ui.select(result, {
        format_item = function(item)
          return item.title
        end,
      }, function(item)
        if item ~= nil then
          action(vim.fs.joinpath(client.root_dir, item.path), item.title)
        end
      end)
    end
  )
end
return ---@type vim.lsp.Config
{
  cmd = { ---@type string[]
    'zk',
    'lsp',
  },
  filetypes = { ---@type string[]
    'markdown',
  },
  root_markers = { ---@type string[]
    '.zk',
  },
  workspace_required = true, ---@type boolean
  ---@param client vim.lsp.Client
  on_attach = function(client, bufnr) ---@param bufnr integer
    vim.api.nvim_buf_create_user_command(bufnr, 'LspZkIndex', function()
      client:exec_cmd({
        title = 'ZkIndex',
        command = 'zk.index',
        arguments = {
          vim.api.nvim_buf_get_name(bufnr),
        },
      }, {
        bufnr = bufnr,
      }, function(err, result)
        if err ~= nil then
          vim.api.nvim_echo({ { 'zk.index error\n' }, { vim.inspect(err) } }, true, {})
          return
        end
        if result ~= nil then
          vim.api.nvim_echo({ { vim.inspect(result) } }, false, {})
        end
      end)
    end, { desc = 'ZkIndex' })
    vim.api.nvim_buf_create_user_command(bufnr, 'LspZkList', function()
      zk_list(client, bufnr, {}, function(path)
        vim.cmd('edit ' .. path)
      end)
    end, {
      desc = 'ZkList',
    })
    vim.api.nvim_buf_create_user_command(bufnr, 'LspZkNew', function(args)
      local title = #args.fargs >= 1 and args.fargs[1] or ''
      local dir = #args.fargs >= 2 and args.fargs[2] or ''
      client:exec_cmd({
        title = 'ZkNew',
        command = 'zk.new',
        arguments = {
          vim.api.nvim_buf_get_name(bufnr),
          { title = title, dir = dir },
        },
      }, { bufnr = bufnr }, function(err, result)
        if err ~= nil then
          vim.api.nvim_echo({
            { 'zk.new error\n' },
            { vim.inspect(err) },
          }, true, {})
          return
        end
        vim.cmd('edit ' .. result.path)
      end)
    end, {
      desc = 'ZkNew [title] [dir]',
      nargs = '*',
    })
  end,
}