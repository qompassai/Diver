local gh = function(repo)
  return 'https://github.com/' .. repo
end
vim.pack.add({
  {
    src = gh('ibhagwan/fzf-lua'),
    version = 'main',
    hook = function()
      local fzf_config = require('config.nav.fzf')
      fzf_config.fzf_setup()
      for _, keymap in ipairs(fzf_config.keymaps) do
        vim.keymap.set(keymap[1], keymap[2], keymap[3], keymap[4] or {})
      end
    end,
    cmd = { 'FzfLua' },
  },

  -- Neo-tree
  {
    src = gh('nvim-neo-tree/neo-tree.nvim'),
    branch = 'v3.x',
    version = 'v3.x',
    hook = function()
      require('neo-tree').setup(require('config.nav.neotree').neotree_cfg())
    end,
    cmd = {
      'Neotree',
      'NeoTreeClose',
      'NeoTreeFloat',
      'NeoTreeFocus',
      'NeoTreeReveal',
      'NeoTreeShow',
    },
  },

  {
    src = gh('s1n7ax/nvim-window-picker'),
    version = vim.version.range('2.*'),
    hook = function()
      require('window-picker').setup({
        filter_rules = {
          autoselect_one = true,
          bo = {
            buftype = {
              'quickfix',
              'terminal',
            },
            filetype = {
              'neo-tree',
              'neo-tree-popup',
              'notify',
            },
          },
          include_current_win = true,
        },
      })
    end,
  },

  {
    src = gh('MunifTanjim/nui.nvim'),
    version = 'main',
  },
  {
    src = gh('nvim-lua/plenary.nvim'),
    version = 'master',
  },
  {
    src = gh('nvim-tree/nvim-web-devicons'),
    version = 'master',
  },
}, {
  confirm = false,
  load = true,
})

vim.api.nvim_create_user_command('FzfLua', function(opts)
  local fzf = require('fzf-lua')
  local action = opts.args ~= '' and opts.args or 'files'
  fzf[action]()
end, {
  nargs = '*',
  complete = function(arg_lead, cmd_line, cursor_pos)
    return require('fzf-lua').complete(arg_lead, cmd_line, cursor_pos)
  end,
  desc = 'FzfLua fuzzy finder',
})