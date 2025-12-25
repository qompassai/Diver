-- qompassai/Diver/lua/config/lang/cmp.lua
-- Qompass AI Diver Lang Completion Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
function M.blink_cmp()
  return {
    keymap = {
      preset = 'default'
    },
    appearance = {
      nerd_font_variant = 'mono',
      kind_icons = require('lazyvim.config').icons.kinds,
    },
    completion = {
      documentation = {
        auto_show = true
      },
    },
    snippets = { preset = 'luasnip' },
    sources = {
      default = {
        'lazydev',
        'lsp',
        'path',
        'snippets',
        'buffer',
        'dadbod',
        'emoji',
        'dictionary',
      },
      providers = {
        lazydev = {
          name = 'LazyDev',
          module = 'lazydev.integrations.blink',
          score_offset = 1001,
        },
        lsp = {
          name = 'lsp',
          enabled = true,
          module = 'blink.cmp.sources.lsp',
          min_keyword_length = 3,
          score_offset = 2000,
        },
        path = {
          name = 'Path',
          enabled = true,
          module = 'blink.cmp.sources.path',
          score_offset = 250,
          fallbacks = {
            'snippets',
            'buffer'
          },
          opts = {
            trailing_slash = true,
            label_trailing_slash = true,
            get_cwd = function(context)
              return vim.fn.expand(('#%d:p:h'):format(context.bufnr))
            end,
            show_hidden_files_by_default = true,
          },
        },
        buffer = {
          name = 'Buffer',
          enabled = true,
          max_items = 3,
          module = 'blink.cmp.sources.buffer',
          min_keyword_length = 3,
          score_offset = 500,
        },
        snippets = {
          name = 'snippets',
          enabled = true,
          max_items = 15,
          min_keyword_length = 3,
          module = 'blink.cmp.sources.snippets',
          score_offset = 750,
        },
        dadbod = {
          name = 'Dadbod',
          enabled = true,
          module = 'vim_dadbod_completion.blink',
          min_keyword_length = 3,
          score_offset = 85,
        },
        emoji = {
          module = 'blink-emoji',
          name = 'Emoji',
          enabled = true,
          score_offset = 93,
          min_keyword_length = 3,
          opts = { insert = true },
        },
        dictionary = {
          module = 'blink-cmp-dictionary',
          name = 'Dict',
          score_offset = 20,
          enabled = true,
          max_items = 8,
          min_keyword_length = 3,
          opts = {
            dictionary_directories = {
              vim.fn.expand('\'$HOME/.config/nvim/lua/utils/dictionary\''),
            },
            dictionary_files = {
              vim.fn.expand('\'$HOME/.config/nvim/spell/en.utf-8.add\''),
            },
          },
        },
      },
    },
    cmdline = {
      enabled = true,
    },
    -- fuzzy = {
    --   use_typo_resistance = false,
    --   use_frecency = true,
    --   use_proximity = false,
    -- },
  }
end

function M.nvim_cmp()
  local cmp = require('cmp')
  local luasnip = require('luasnip')
  local mappings = {
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<CR>'] = cmp.mapping.confirm({
      select = true,
      behavior = cmp.ConfirmBehavior.Replace,
    }),
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { 'i', 's' }),
  }
  vim.lsp.completion.enable = true
  cmp.setup({
    snippet = {
      expand = function(args)
        luasnip.lsp_expand(args.body)
      end,
    },
    mapping = mappings,
    --[[
    sources = cmp.config.sources({
      {
        name = 'nvim_lsp',
        priority = 1000,
      },
      {
        name = 'luasnip',
        priority = 750,
      },
      {
        name = 'buffer',
        priority = 500,
      },
      {
        name = 'path',
        priority = 250,
      },
    }),
    ]] --
    formatting = {
      format = require('lspkind').cmp_format({
        mode = 'symbol_text',
        maxwidth = 50,
        ellipsis_char = '...',
        before = function(entry, vim_item)
          vim_item.menu = ({
            nvim_lsp = '[LSP]',
            nvim_lua = '[Lua]',
            luasnip = '[Snippet]',
            buffer = '[Buffer]',
            path = '[Path]',
          })[entry.source.name]
          return vim_item
        end,
      }),
    },
    experimental = {
      ghost_text = {
        hl_group = 'Comment',
      },
    },
    window = {
      completion = cmp.config.window.bordered({
        border = 'single',
        winhighlight = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None',
      }),
      documentation = cmp.config.window.bordered({
        border = 'single',
        winhighlight = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None',
      }),
    },
  })
  --[[
  cmp.setup.filetype('lua', {
    sources = cmp.config.sources({
      { name = 'nvim_lua', priority = 1100 },
      { name = 'nvim_lsp', priority = 1000 },
      { name = 'luasnip',  priority = 900 },
      { name = 'buffer',   priority = 800 },
    }),
  })
  cmp.setup.filetype({
    'typescript',
    'typescriptreact',
  }, {
    sources = cmp.config.sources({
      {
        name = 'nvim_lsp',
        priority = 1000,
      },
      { name = 'luasnip', priority = 900 },
      { name = 'buffer',  priority = 800 },
    }),
  })
  cmp.setup.filetype('zig', {
    sources = cmp.config.sources({
      { name = 'nvim_lsp', priority = 1000 },
      { name = 'luasnip',  priority = 750 },
      { name = 'buffer',   priority = 500 },
      { name = 'path',     priority = 250 },
    }),
  })
  cmp.setup.cmdline(':', {
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources({ { name = 'path' }, { name = 'cmdline' } }),
  })
  cmp.setup.cmdline('/', {
    mapping = cmp.mapping.preset.cmdline(),
    sources = { { name = 'buffer' } },
  })

--]]
end

return M