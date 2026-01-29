-- /qompassai/Diver/lua/plugins/nav/fzf.lua
-- Qompass AI Diver Nav FZF Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
    'ibhagwan/fzf-lua',
    lazy = false,
    dependencies = {
        'nvim-tree/nvim-web-devicons',
    },
    cmd = 'FzfLua',
    keys = function()
        return require('config.nav.fzf').keymaps
    end,
    config = function()
        require('config.nav.fzf').fzf_setup()
    end,
}
--[[
{
  {
    src = "https://github.com/ibhagwan/fzf-lua",
    -- version = 'main',
    data = {
      cmd = 'FzfLua',
      deps = { 'nvim-web-devicons' },
      config = 'config.nav.fzf',
      keys = true,
    },
  },
  { src = "https://github.com/nvim-tree/nvim-web-devicons" },
}
vim.api.nvim_create_user_command('FzfLua', function(opts)
  vim.cmd.packadd('fzf-lua')
  vim.cmd.packadd("nvim-web-devicons")
  require("config.nav.fzf").fzf_setup()
  require("fzf-lua")[opts.args ~= "" and opts.args or "files"]()
end, { nargs = "*", complete = "customlist,v:lua.require'fzf-lua'.complete" })

--]]
