-- /qompassai/Diver/lua/config/nav/harpoon.lua
-- Qompass AI Diver Harpoon Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.harpoon()
  require('harpoon').setup({
    global_settings = {
      save_on_toggle = true,
      save_on_change = true,
      enter_on_sendcmd = true,
      tmux_autoclose_windows = true,
      excluded_filetypes = { 'harpoon' },
      mark_branch = true,
      tabline = true,
      tabline_prefix = ' ⍟ ',
      tabline_suffix = ' ✦ '
    },
    menu = { width = vim.api.nvim_win_get_width(0) - 10 },
    projects = {
      [os.getenv('HOME') .. '/.GH/Qompass/project-a'] = {
        term = { cmds = { './start-server.sh', 'npm run watch' } }
      },
      [os.getenv('HOME') .. '/.GH/Qompass/client-project'] = {
        term = { cmds = { 'make build', 'docker-compose up' } }
      }
    }
  })
end

return M