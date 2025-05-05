-- ~/.config/nvim/lua/config/ui/html.lua
----------------------------------------
local M = {}
local is_nightly = vim.fn.has('nvim-0.10') == 1
function M.html_none_ls_sources(opts)
  opts = opts or {}
  local null_ls_ok, null_ls = pcall(require, "null-ls")
  if not null_ls_ok then return {} end
  local nlsb = null_ls.builtins
  local utils = require("null-ls.utils")
  local prettierConfig = {
    prefer_local = "node_modules/.bin",
    cwd = utils.root_pattern(
      ".prettierrc",
      ".prettierrc.json",
      ".prettierrc.yml",
      ".prettierrc.yaml",
      ".prettierrc.json5",
      ".prettierrc.js",
      ".prettierrc.cjs",
      "prettier.config.js",
      "prettier.config.cjs",
      "package.json"
    ),
  }
  local prettierd = nlsb.formatting.prettierd.with(vim.tbl_extend("force", prettierConfig, {
    ft = "html",
    runtime_condition = function(_)
      return utils.executable("prettierd")
    end,
  }))
  local prettier = nlsb.formatting.prettier.with(vim.tbl_extend("force", prettierConfig, {
    ft = "html",
    runtime_condition = function(_)
      return not utils.executable("prettierd")
    end,
  }))
  return {
    prettierd,
    prettier,
    require("null-ls").builtins.diagnostics.htmlhint,
    nlsb.diagnostics.trail_space.with({
      ft = "html",
    }),
  }
end
function M.html_lint(opts)
  opts = opts or {}
  local config = {
    underline = true,
    virtual_text = true,
    signs = true,
    update_in_insert = false,
  }
  vim.diagnostic.config(config)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "html" },
    callback = function()
      vim.diagnostic.config({
        severity_sort = true,
        float = { border = "rounded" },
      })
    end
  })
end
function M.html_lsp(on_attach, capabilities)
  local lspconfig = require("lspconfig")
  lspconfig.html.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    filetypes = { "html", "handlebars", "htmldjango", "blade", "erb", "ejs" },
    init_options = {
      configurationSection = { "html", "css"  },
      embeddedLanguages = {
        css = true,
        javascript = true,
      },
      provideFormatter = true,
    },
  })

  lspconfig.emmet_ls.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    ft = { "html", "javascriptreact", "typescriptreact", "haml",
      "xml", "xsl", "pug", "slim", "erb", "vue", "svelte" },
  })
end
function M.html_completion(opts)
  opts = opts or {}
  local completion_ok, completion = pcall(require, "config.completion")
  if not completion_ok then return end

  local htmx_attributes = {
    { label = "hx-get", insertText = 'hx-get="${1:url}"' },
    { label = "hx-post", insertText = 'hx-post="${1:url}"' },
    { label = "hx-put", insertText = 'hx-put="${1:url}"' },
    { label = "hx-delete", insertText = 'hx-delete="${1:url}"' },
    { label = "hx-trigger", insertText = 'hx-trigger="${1:event}"' },
    { label = "hx-swap", insertText = 'hx-swap="${1:innerHTML}"' },
    { label = "hx-target", insertText = 'hx-target="${1:selector}"' },
  }
  local completion_module = completion ---@type table
  ---@diagnostic disable-next-line: undefined-field
  completion_module.register_custom_source('htmx', {
    ---@diagnostic disable-next-line: unused-local
    get_items = function(ctx, callback)
      callback({
        items = htmx_attributes,
        is_incomplete = false
      })
    end
  })
end
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "html" },
    callback = function()
      if pcall(require, "blink.cmp") then
        require("blink.cmp").setup({
          sources = {
            providers = {
              htmx = {
                enabled = true
              }
            }
          }
        })
      end
    end
  })
function M.html_treesitter(opts)
  opts = opts or {}
  local ts_ok, ts_configs = pcall(require, "nvim-treesitter.configs")
  if ts_ok then
    ts_configs.setup({
      autotag = {
        enable = true,
      },
      sync_install = true,
      ignore_install = {},
      auto_install = true,
      modules = {},
      ensure_installed = "html",
      highlight = {
        enable = true,
      },
    })
  end
end
function M.html_emmet(opts)
  opts = opts or {}
  vim.g.user_emmet_settings = {
    variables = {
      lang = "en",
    },
    html = {
      default_attributes = {
        option = { value = nil },
        textarea = { id = nil, name = nil, cols = 10, rows = 10 },
      },
      snippets = {
        ["!"] = "<!DOCTYPE html>\n<html lang=\"${lang}\">\n<head>\n\t<meta charset=\"UTF-8\">\n\t<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n\t<title>${1:Document}</title>\n\t<script src=\"https://unpkg.com/htmx.org@1.9.6\"></script>\n</head>\n<body>\n\t${0}\n</body>\n</html>",
        ["htmx"] = "<div hx-${1:get}=\"${2:url}\" hx-trigger=\"${3:event}\" hx-target=\"${4:#target}\">\n\t${0}\n</div>",
      },
    },
  }
  vim.g.user_emmet_leader_key = "<C-z>"
  vim.g.user_emmet_mode = "a"
end
function M.html_preview(opts)
   opts = opts or {}
  local preview_opts = opts.preview or {}
  local livepreview_ok, livepreview = pcall(require, "livepreview.config")
  if livepreview_ok then
    livepreview.set({
      port = preview_opts.port or 8090,
      browser_cmd = preview_opts.browser_cmd,
      auto_start = preview_opts.auto_start or false,
      refresh_delay = preview_opts.refresh_delay or 150,
      allowed_file_types = preview_opts.allowed_file_types or { "html", "markdown", "asciidoc", "svg" }
    })
  end
end
function M.html_conform(opts)
  opts = opts or {}
  local conform_ok, _ = pcall(require, "conform")
  if conform_ok then
    ---@type table
    local conform = require("conform")
    conform.setup({
      formatters_by_ft = {
        html = { "prettierd" },
      }
    })
  end
end
function M.setup_html(opts)
  opts = opts or {}
  M.html_none_ls_sources(opts)
  M.html_completion(opts)
  M.html_lint(opts)
  M.html_conform(opts)
  M.html_emmet(opts)
  M.html_lsp(opts.on_attach, opts.capabilities)
  M.html_preview(opts)
  M.html_treesitter(opts)
  if is_nightly then
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "html" },
      callback = function()
        vim.o.formatexpr = "v:lua.require'null-ls'.formatter"
      end
    })
  end
end
return M
