-- ~/.config/nvim/lua/config/cmp.lua
------------------------------------
local M = {}
---@return table
function M.blink_config()
  return {
    keymap = { preset = 'default' },
    appearance = {
      nerd_font_variant = 'mono',
      kind_icons = require('lazyvim.config').icons.kinds,
    },
    completion = {
      documentation = { auto_show = true },
    },
    sources = {
      default = { 'lsp', 'snippets', 'buffer', 'path' },
      providers = {
        lsp = { score_offset = 1000 },
        snippets = { score_offset = 750 },
        buffer = { score_offset = 500 },
        path = { score_offset = 250 },
      },
      per_filetype = {
        lua = { 'lsp', 'nvim_lua', 'luasnip' },
      }
    },
    fuzzy = { implementation = 'lua' },
  }
end
function M.nvim_cmp_setup()
  local cmp = require('cmp')
  cmp.setup({
    snippet = {
      expand = function(args)
        require('luasnip').lsp_expand(args.body)
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ['<C-b>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.abort(),
      ['<CR>'] = cmp.mapping.confirm({ select = true }),
      ['<Tab>'] = cmp.mapping.select_next_item(),
      ['<S-Tab>'] = cmp.mapping.select_prev_item(),
    }),
    sources = cmp.config.sources({
      { name = 'nvim_lsp' },
      { name = 'luasnip' },
      { name = 'buffer' },
      { name = 'path' },
    }),
    formatting = {
      format = require('lspkind').cmp_format({
        mode = 'symbol_text',
        maxwidth = 50,
        ellipsis_char = '...',
      }),
    },
    experimental = {
      ghost_text = true,
    },
    window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    }
  })
  cmp.setup.filetype('lua', {
    sources = cmp.config.sources({
      { name = 'nvim_lua', priority = 1000 },
      { name = 'nvim_lsp', priority = 900 },
      { name = 'luasnip', priority = 800 },
    })
  })
   cmp.setup.filetype('typescript', {
    sources = cmp.config.sources({
      { name = 'nvim_lsp', priority = 1000 },
      { name = 'luasnip', priority = 800 },
      { name = 'buffer', priority = 700 },
    })
  })
  cmp.setup.filetype('typescriptreact', {
    sources = cmp.config.sources({
      { name = 'nvim_lsp', priority = 1000 },
      { name = 'luasnip', priority = 800 },
      { name = 'buffer', priority = 700 },
    })
  })
end
return M
