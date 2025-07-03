-- /qompassai/Diver/lua/config/ui/css.lua
-- Qompass AI Diver CSS Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}

local function xdg_config(path)
  return vim.fn.expand(vim.env.XDG_CONFIG_HOME or '~/.config') .. "/" .. path
end
local tailwind_config = vim.fn.expand("$XDG_CONFIG_HOME/tailwind/tailwind.config.js")
function M.css_autocmds()
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'css', 'scss', 'less' },
    callback = function()
      vim.opt_local.tabstop = 2
      vim.opt_local.shiftwidth = 2
      vim.opt_local.expandtab = true
    end
  })
end

function M.css_null_ls(opts)
  opts = opts or {}
  local null_ls = require('null-ls')
  local b = null_ls.builtins
  local defaults = {
    b.formatting.biome.with({
      ft = { 'css', 'scss', 'less' },
      prefer_local = 'node_modules/.bin',
    }),
    b.diagnostics.stylelint.with({
      ft = { 'css', 'scss', 'less' },
    }),
    b.formatting.stylelint.with({
      ft = { 'css', 'scss', 'less' },
    }),
    b.diagnostics.trail_space.with({
      ft = { 'css', 'scss', 'less' },
    }),
  }

  if opts.sources and type(opts.sources) == "table" then
    return opts.sources
  end

  return defaults
end

function M.css_lsp(on_attach, capabilities)
  local lspconfig = require('lspconfig')
  local util = require('lspconfig.util')

  lspconfig.cssls.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    filetypes = { 'css', 'scss', 'less' },
    settings = {
      css = {
        validate = true,
        lint = {
          compatibleVendorPrefixes = 'warning',
          vendorPrefix = 'warning',
          duplicateProperties = 'warning',
          emptyRules = 'warning',
        },
      },
      scss = { validate = true },
      less = { validate = true },
    },
  })

  lspconfig.tailwindcss.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    cmd = { 'tailwindcss-language-server', '--stdio' },
    ft = {
      'aspnetcorerazor', 'astro', 'astro-markdown', 'blade', 'django-html', 'htmldjango', 'edge', 'eelixir', 'ejs', 'erb',
      'eruby', 'gohtml', 'handlebars', 'hbs', 'html', 'htmlangular', 'html-eex', 'heex', 'liquid', 'mustache', 'njk',
      'php', 'razor', 'slim', 'twig', 'css', 'less', 'postcss', 'sass', 'scss', 'stylus', 'javascript', 'javascriptreact',
      'typescript', 'typescriptreact', 'vue', 'svelte'
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
        classAttributes = { 'class', 'className', 'class:list', 'classList', 'ngClass' },
        includeLanguages = {
          eelixir = 'html-eex',
          eruby = 'erb',
          templ = 'html',
          htmlangular = 'html',
        },
      },
    },
    on_new_config = function(new_config)
      new_config.settings = new_config.settings or {}
      new_config.settings.editor = new_config.settings.editor or {}
      new_config.settings.editor.tabSize =
          new_config.settings.editor.tabSize or vim.lsp.util.get_effective_tabstop()
    end,
    root_dir = function(fname)
      local root_file = {
        'tailwind.config.js', 'tailwind.config.cjs', 'tailwind.config.mjs', 'tailwind.config.ts',
        'postcss.config.js', 'postcss.config.cjs', 'postcss.config.mjs', 'postcss.config.ts',
      }
      root_file = util.insert_package_json(root_file, 'tailwindcss', fname)
      return util.root_pattern(unpack(root_file))(fname)
    end,
  })
end

function M.css_treesitter(opts)
  opts = opts or {}
  local ts_ok, ts_configs = pcall(require, 'nvim-treesitter.configs')
  if not ts_ok then return end
  local default_opts = {
    sync_install = true,
    auto_install = true,
    ensure_installed = { 'css', 'scss' },
    highlight = { enable = true },
  }

  local merged_opts = vim.tbl_deep_extend("force", default_opts, opts)
  ts_configs.setup(merged_opts)
end

function M.css_colorizer(opts)
  opts = opts or {}
  local ok, colorizer = pcall(require, "colorizer")
  if not ok then return end
  local default_opts = {
    filetypes = {
      "css", "scss", "sass", "less", "stylus", "html", "javascript", "typescript", "jsx", "tsx", "vue",
      "svelte", "astro", "php", "lua", "vim"
    },
    user_default_options = {
      RGB = true,
      RRGGBB = true,
      names = true,
      RRGGBBAA = true,
      AARRGGBB = true,
      rgb_fn = true,
      hsl_fn = true,
      css = true,
      css_fn = true,
      mode = "background",
      tailwind = true,
      sass = { enable = true, parsers = { "css" } },
      virtualtext = "■",
      always_update = true,
    },
    buftypes = {},
  }
  local merged = vim.tbl_deep_extend("force", default_opts, opts)
  colorizer.setup(merged)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = merged.filetypes,
    callback = function() colorizer.attach_to_buffer(0) end,
  })
end

function M.css_conform(opts)
  opts = opts or {}
  local function merge_config(defaults, overrides)
    return vim.tbl_deep_extend("force", defaults, overrides or {})
  end

  return {
    biome_css = merge_config({
      command = "biome",
      args = { "format", "--stdin-file-path", "$FILENAME" },
      cwd = xdg_config("biome"),
    }, opts.biome_css),

    stylelint = merge_config({
      command = "stylelint",
      args = { "--fix", "--stdin", "--stdin-filename", "$FILENAME" },
      cwd = xdg_config("stylelint"),
      require_cwd = false,
    }, opts.stylelint),

    prettierd = merge_config({
      command = "prettierd",
      args = { "$FILENAME" },
      cwd = vim.fn.getcwd(),
      prefer_local = "node_modules/.bin",
    }, opts.prettierd),
  }
end

function M.css_config(opts)
  opts = opts or {}
  M.css_autocmds()
  M.css_colorizer(opts.colorizer)
  M.css_lsp(opts.on_attach, opts.capabilities)
  M.css_treesitter(opts.treesitter)
  return {
    setup = M.css_config,
    null_ls = M.css_null_ls,
    conform = M.css_conform,
    lsp = M.css_lsp,
    treesitter = M.css_treesitter,
    colorizer = M.css_colorizer,
    autocmds = M.css_autocmds,
  }
end

return M
