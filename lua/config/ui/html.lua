-- /qompassai/Diver/lua/config/ui/html.lua
----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
local M = {}
local is_nightly = vim.fn.has("nvim-0.10") == 1
function M.html_none_ls_sources(opts)
  opts = opts or {}
  local null_ls_ok, null_ls = pcall(require, "none-ls")
  if not null_ls_ok then
    vim.notify("none-ls not available", vim.log.levels.WARN)
    return {}
  end
  local nlsb = null_ls.builtins
  local utils = require("none-ls.utils")
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
  return { prettierd, prettier }
end
function M.html_lint(opts)
  opts = opts or {}
  local config = {
    underline = true,
    virtual_text = true,
    signs = true,
    update_in_insert = true,
  }
  vim.diagnostic.config(config)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "html" },
    callback = function()
      vim.diagnostic.config({
        severity_sort = true,
        float = { border = "rounded" },
      })
    end,
  })
end

function M.html_lsp(on_attach, capabilities)
  local lspconfig_ok, lspconfig = pcall(require, "lspconfig")
  if not lspconfig_ok then
    vim.notify("lspconfig not available", vim.log.levels.WARN)
    return
  end
  lspconfig.html.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    filetypes = { "html", "handlebars", "htmldjango", "blade", "erb", "ejs" },
    init_options = {
      configurationSection = { "html", "css" },
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
    filetypes = {
      "html",
      "javascriptreact",
      "typescriptreact",
      "haml",
      "xml",
      "xsl",
      "pug",
      "slim",
      "erb",
      "vue",
      "svelte",
    },
  })
end

function M.html_completion(opts)
  opts = opts or {}
  local htmx_attributes = {
    { label = "hx-get", insertText = 'hx-get="${1:url}"', kind = vim.lsp.protocol.CompletionItemKind.Property },
    { label = "hx-post", insertText = 'hx-post="${1:url}"', kind = vim.lsp.protocol.CompletionItemKind.Property },
    { label = "hx-put", insertText = 'hx-put="${1:url}"', kind = vim.lsp.protocol.CompletionItemKind.Property },
    {
      label = "hx-delete",
      insertText = 'hx-delete="${1:url}"',
      kind = vim.lsp.protocol.CompletionItemKind.Property,
    },
    {
      label = "hx-trigger",
      insertText = 'hx-trigger="${1:event}"',
      kind = vim.lsp.protocol.CompletionItemKind.Property,
    },
    {
      label = "hx-swap",
      insertText = 'hx-swap="${1:innerHTML}"',
      kind = vim.lsp.protocol.CompletionItemKind.Property,
    },
    {
      label = "hx-target",
      insertText = 'hx-target="${1:selector}"',
      kind = vim.lsp.protocol.CompletionItemKind.Property,
    },
    {
      label = "hx-select",
      insertText = 'hx-select="${1:selector}"',
      kind = vim.lsp.protocol.CompletionItemKind.Property,
    },
    {
      label = "hx-confirm",
      insertText = 'hx-confirm="${1:message}"',
      kind = vim.lsp.protocol.CompletionItemKind.Property,
    },
    {
      label = "hx-indicator",
      insertText = 'hx-indicator="${1:selector}"',
      kind = vim.lsp.protocol.CompletionItemKind.Property,
    },
  }
end
function M.html_treesitter(opts)
  opts = opts or {}
  local ts_ok, ts_configs = pcall(require, "nvim-treesitter.configs")
  if not ts_ok then
    vim.notify("nvim-treesitter not available", vim.log.levels.WARN)
    return
  end
  ts_configs.setup({
    autotag = {
      enable = true,
      enable_rename = true,
      enable_close = true,
      enable_close_on_slash = true,
    },
    sync_install = true,
    ignore_install = {},
    auto_install = true,
    modules = {},
    ensure_installed = { "html", "css", "javascript", "typescript" },
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
    indent = {
      enable = true,
    },
  })
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
        ["!"] = '<!DOCTYPE html>\n<html lang="${lang}">\n<head>\n\t<meta charset="UTF-8">\n\t<meta name="viewport" content="width=device-width, initial-scale=1.0">\n\t<title>${1:Document}</title>\n\t<script src="https://unpkg.com/htmx.org@1.9.6"></script>\n</head>\n<body>\n\t${0}\n</body>\n</html>',
        ["htmx"] = '<div hx-${1:get}="${2:url}" hx-trigger="${3:event}" hx-target="${4:#target}">\n\t${0}\n</div>',
        ["hx-form"] = '<form hx-${1:post}="${2:url}" hx-target="${3:#result}">\n\t${0}\n</form>',
        ["hx-button"] = '<button hx-${1:get}="${2:url}" hx-target="${3:#target}">${4:Click me}</button>',
      },
    },
  }
  vim.g.user_emmet_leader_key = "<C-z>"
  vim.g.user_emmet_mode = "a"
end
opts = opts or {}
local preview_opts = opts.preview or {}
local livepreview_ok, livepreview = pcall(require, "livepreview.config")
if livepreview_ok then
  livepreview.set({
    port = preview_opts.port or 8090,
    browser_cmd = preview_opts.browser_cmd,
    auto_start = preview_opts.auto_start or false,
    refresh_delay = preview_opts.refresh_delay or 150,
    allowed_file_types = preview_opts.allowed_file_types or { "html", "markdown", "asciidoc", "svg" },
  })
else
  vim.notify("livepreview not available", vim.log.levels.WARN)
end

function M.html_conform(opts)
  opts = opts or {}
  local conform_ok, conform = pcall(require, "conform")
  if not conform_ok then
    vim.notify("conform not available", vim.log.levels.WARN)
    return
  end
end
M.default_opts = {
  lsp = {
    on_attach = function(client, bufnr)
      local bufmap = function(mode, lhs, rhs)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr })
      end
      bufmap("n", "gd", vim.lsp.buf.definition)
      bufmap("n", "K", vim.lsp.buf.hover)
    end,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
  },
  conform = {
    formatters_by_ft = {
      html = { "prettierd", "djlint" },
      htmldjango = { "djlint" },
    },
    formatters = {
      djlint = {
        command = "djlint",
        args = { "--reformat", "-" },
      },
    },
  },
  lint = {
    virtual_text = true,
    underline = true,
    update_in_insert = false,
  },
  treesitter = {
    auto_install = true,
    ensure_installed = { "html", "htmldjango" },
  },
  preview = {
    port = 8080,
    auto_start = true,
  },
}
function M.setup_html(user_opts)
  local merged_opts = vim.tbl_deep_extend("force", M.default_opts, user_opts or {})

  M.html_lsp(merged_opts.lsp.on_attach, merged_opts.lsp.capabilities)
  require("conform").setup(merged_opts.conform)
  vim.diagnostic.config(merged_opts.lint)
  require("nvim-treesitter.configs").setup(merged_opts.treesitter)
  M.html_preview(merged_opts.preview)
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
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "html" },
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      vim.keymap.set("n", "<leader>cf", function()
        require("conform").format({ bufnr = buf })
      end, { buffer = buf, desc = "Format HTML" })
      vim.keymap.set("i", "<C-z>,", "<C-y>,", { buffer = buf, desc = "Emmet expand" })
      vim.keymap.set("n", "<leader>cp", function()
        vim.cmd("LivePreviewToggle")
      end, { buffer = buf, desc = "Toggle live preview" })
    end,
  })
  if is_nightly then
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "html" },
      callback = function()
        vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
      end,
    })
  end
  vim.notify("HTML configuration loaded successfully", vim.log.levels.INFO)
end
return M
