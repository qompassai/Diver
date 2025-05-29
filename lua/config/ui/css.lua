-- ~/.config/nvim/lua/config/ui/css.lua

local M = {}

--Autocmds
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "css", "scss", "less" },
    callback = function()
      vim.opt_local.tabstop = 2
      vim.opt_local.shiftwidth = 2
      vim.opt_local.expandtab = true

    end,
  })
--
local null_ls = require("null-ls")
local b = null_ls.builtins

function M.none_ls_sources()
  return {
    b.formatting.prettierd.with({
      ft = { "css", "scss", "less" },
      prefer_local = "node_modules/.bin",
    }),
    b.diagnostics.stylelint.with({
      ft = { "css", "scss", "less" },
    }),
    b.formatting.stylelint.with({
      ft = { "css", "scss", "less" },
    }),
    b.diagnostics.trail_space.with({
      ft = { "css", "scss", "less" },
    }),
  }
end

function M.setup_lsp(on_attach, capabilities)
  local lspconfig = require("lspconfig")
  local util = require("lspconfig.util")
  lspconfig.cssls.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    filetypes = { "css", "scss", "less" },
    settings = {
      css = {
        validate = true,
        lint = {
          compatibleVendorPrefixes = "warning",
          vendorPrefix = "warning",
          duplicateProperties = "warning",
          emptyRules = "warning",
        },
      },
      scss = {
        validate = true,
      },
      less = {
        validate = true,
      },
    },
  });
   lspconfig.tailwindcss.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    cmd = { 'tailwindcss-language-server', '--stdio' },
    ft = {
      'aspnetcorerazor', 'astro', 'astro-markdown', 'blade', 'django-html',
      'htmldjango', 'edge', 'eelixir', 'ejs', 'erb', 'eruby', 'gohtml',
      'handlebars', 'hbs', 'html', 'htmlangular', 'html-eex',
      'heex', 'liquid', 'markdown', 'mdx', 'mustache', 'njk',
      'php', 'razor', 'slim', 'twig',
      'css', 'less', 'postcss', 'sass', 'scss', 'stylus',
      'javascript', 'javascriptreact', 'typescript', 'typescriptreact',
      'vue', 'svelte',
    },
    settings = {
      tailwindCSS = {
        validate = true,
        lint = {
          cssConflict = 'warning',
          invalidApply = 'error',
          invalidScreen = 'error',
          invalidVariant = 'error',
          invalidConfigPath = 'error',
          invalidTailwindDirective = 'error',
          recommendedVariantOrder = 'warning',
        },
        classAttributes = {
          'class',
          'className',
          'class:list',
          'classList',
          'ngClass',
        },
        includeLanguages = {
          eelixir = 'html-eex',
          eruby = 'erb',
          templ = 'html',
          htmlangular = 'html',
        },
      },
    },
    on_new_config = function(new_config)
      if not new_config.settings then
        new_config.settings = {}
      end
      if not new_config.settings.editor then
        new_config.settings.editor = {}
      end
      if not new_config.settings.editor.tabSize then
        new_config.settings.editor.tabSize = vim.lsp.util.get_effective_tabstop()
      end
    end,
    root_dir = function(fname)
      local root_file = {
        'tailwind.config.js',
        'tailwind.config.cjs',
        'tailwind.config.mjs',
        'tailwind.config.ts',
        'postcss.config.js',
        'postcss.config.cjs',
        'postcss.config.mjs',
        'postcss.config.ts',
      }
      root_file = util.insert_package_json(root_file, 'tailwindcss', fname)
      return util.root_pattern(unpack(root_file))(fname)
    end,
  })
end

function M.setup_treesitter()
  local ts_ok, ts_configs = pcall(require, "nvim-treesitter.configs")
  if ts_ok then
    ts_configs.setup({
      sync_install = true,
      ignore_install = {},
      auto_install = true,
      modules = {},
      ensure_installed = { "css", "scss" },
      highlight = {
        enable = true,
      },
    })
  end
end

function M.setup_colorizer()
  local colorizer_ok, colorizer = pcall(require, "colorizer")
  if colorizer_ok then
    colorizer.setup({ "css", "scss", "less" }, {
      RGB = true,
      RRGGBB = true,
      names = true,
      RRGGBBAA = true,
      rgb_fn = true,
      hsl_fn = true,
      css = true,
      css_fn = true,
      mode = "background"
    })
  end
end

function M.setup_conform()
  local conform_ok, _ = pcall(require, "conform")
  if conform_ok then
    ---@type table
    local conform = require("conform")
    ---@diagnostic disable-next-line: undefined-field
    conform.setup({
      formatters_by_ft = {
        css = { "prettierd", "stylelint" },
        scss = { "prettierd", "stylelint" },
        less = { "prettierd", "stylelint" },
      }
    })
  end
end

function M.setup(opts)
  opts = opts or {}
  M.setup_lsp(opts.on_attach, opts.capabilities)
  M.setup_treesitter()
  M.setup_colorizer()
  M.setup_conform()

end
return M
