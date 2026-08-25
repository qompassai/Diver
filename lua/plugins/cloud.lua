-- /qompassai/Diver/lua/plugins/cloud.lua
-- Qompass AI Diver Cloud Plugins
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@param repo string
---@return string|vim.pack.Spec
_G.gh = function(repo, opts)
  if opts then
    ---@cast opts vim.pack.Spec
    opts.src = 'https://github.com/' .. repo
    return opts
  end
  return 'https://github.com/' .. repo
end
local add = vim.pack.add
local range = vim.version.range
add({
  gh('chipsenkbeil/distant.nvim', {
    hook = function()
      require('distant'):setup()
    end,
    update = true,
    version = 'v0.3',
  }),
  gh('amitds1997/remote-nvim.nvim', {
    hook = function()
      require('remote-nvim').setup({
        method = 'ssh',
        default_user = os.getenv('USER'),
        picker = 'telescope',
        ssh_config = vim.fn.expand('~/.ssh/config'),
      })
    end,
    update = true,
    version = range('*'),
  }),
  gh('nosduco/remote-sshfs.nvim', {
    hook = function()
      require('remote-sshfs').setup(require('config.cloud.sshfs').opts)
      local sshfs = require('remote-sshfs')
      local fzf = require('fzf-lua')
      vim.keymap.set('n', '<leader>ss', function()
        fzf.fzf_exec(sshfs.list_connections(), {
          prompt = 'SSHFS > ',
          actions = {
            ['default'] = function(selected)
              if selected[1] then
                sshfs.connect(selected[1])
              end
            end,
          },
        })
      end, {
        desc = '[SSHFS] Connect to remote host',
      })
    end,
    update = true,
    version = 'main',
  }),
  gh('samsze0/utils.nvim', {
    update = true,
    version = 'main',
  }),
  gh('samsze0/websocket.nvim', {
    update = true,
    version = 'main',
  }),
}, {
  confirm = false,
  load = true,
})