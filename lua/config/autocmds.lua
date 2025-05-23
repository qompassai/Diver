-- ~/.config/nvim/lua/config/autocmds.lua 
local M = {}
local has_011 = vim.fn.has("nvim-0.11") == 1
local augroups = {
  ansible = vim.api.nvim_create_augroup('AnsibleFT', { clear = true }),
  json = vim.api.nvim_create_augroup('JSON', { clear = true }),
  rust = vim.api.nvim_create_augroup('Rust', { clear = true }),
  python = vim.api.nvim_create_augroup('Python', { clear = true }),
  yaml = vim.api.nvim_create_augroup('YAML', { clear = true }),
  diagnostics = vim.api.nvim_create_augroup('Diagnostics', { clear = true }),
  markdown = vim.api.nvim_create_augroup('MarkdownSettings', { clear = true })
}
M.setup_filetype_detection = function()
  if vim.filetype and vim.filetype.add then
    vim.filetype.add({
      pattern = {
        ['*/playbooks/*.yml'] = 'ansible',
        ['*/tasks/*.yml'] = 'ansible',
        ['*/roles/*.yml'] = 'ansible',
        ['*/handlers/*.yml'] = 'ansible',
        ['*/ansible/*.yml'] = 'ansible',
        ['Dockerfile.*'] = 'dockerfile',
        ['*.Dockerfile'] = 'dockerfile',
        ['Containerfile'] = 'dockerfile',
        ['*.containerfile'] = 'dockerfile',
        ['*.nginx'] = 'nginx',
        ['nginx.conf'] = 'nginx',
        ['/etc/nginx/**/*.conf'] = 'nginx',
        ['.*/waybar/config'] = 'jsonc',
        ['.*/hypr/.*%.conf'] = 'hyprlang',
        ['Cargo.toml'] = 'toml'
      }
    })
  end
end
vim.api.nvim_create_autocmd({"TextChanged", "InsertLeave"}, {
  group = augroups.json,
  pattern = {"*.json", "*.jsonc"},
  callback = function()
    vim.diagnostic.reset()
    if vim.lsp.buf.document_highlight then
      vim.lsp.buf.document_highlight()
    end
    for _, client in ipairs(vim.lsp.get_clients({bufnr = 0})) do
      if client:supports_method("textDocument/semanticTokens") then
        pcall(vim.lsp.buf.semantic_tokens_refresh)
        break
      end
    end
  end,
})
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroups.rust,
  pattern = "*.rs",
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = augroups.rust,
  pattern = "rust",
  callback = function()
    pcall(require, "mappings.rustmap").setup()
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = "lua",
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.expandtab = true
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = augroups.python,
  pattern = "python",
  callback = function()
    vim.opt_local.autoindent = true
    vim.opt_local.smartindent = true
    vim.api.nvim_buf_create_user_command(0, "PythonLint", function()
      vim.lsp.buf.format()
      vim.cmd("write")
      vim.notify("Python code linted and formatted", vim.log.levels.INFO)
    end, {})
    vim.api.nvim_buf_create_user_command(0, "PyTestFile", function()
      local file = vim.fn.expand("%:p")
      vim.cmd("split | terminal pytest " .. file)
    end, {})
    vim.api.nvim_buf_create_user_command(0, "PyTestFunc", function()
      local file = vim.fn.expand("%:p")
      local cmd = "pytest " .. file .. "::" .. vim.fn.expand("<cword>") .. " -v"
      vim.cmd("split | terminal " .. cmd)
    end, {})
  end,
})
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  group = augroups.ansible,
  pattern = {"*/playbooks/*.yml", "*/tasks/*.yml", "*/roles/*.yml", "*/handlers/*.yml", "*/ansible/*.yml"},
  callback = function()
    vim.bo.filetype = "ansible"
  end,
})
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  group = augroups.yaml,
  pattern = {"*.yml", "*.yaml"},
  callback = function()
    local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, 30, false), "\n")
    if content:match("ansible_") or (content:match("hosts:") and content:match("tasks:")) then
      vim.bo.filetype = "yaml.ansible"
    elseif content:match("apiVersion:") and content:match("kind:") then
      vim.bo.filetype = "yaml.kubernetes"
    elseif content:match("version:") and content:match("services:") then
      vim.bo.filetype = "yaml.docker"
    end
  end
})
vim.api.nvim_create_autocmd("BufNewFile", {
  pattern = "*",
  callback = function()
    local filename = vim.fn.expand("%:t")
    local filetype = vim.bo.filetype
    local ext = vim.fn.expand("%:e")
    local comment = "#"
    local header = {}

    local comment_map = {
      lua = "--",
      c = "//",
      cpp = "//",
      rust = "//",
      vim = "\"",
      dosini = ";",
      conf = "#",
      tex = "%",
      glsl = "//",
      mojo = "#",
      zig = "//",
      markdown = "<!--",
      html = "<!--",
      css = "/*",
      yaml = "#",
      yml = "#",
      python = "#",
      go = "//",
      typescript = "//",
      javascript = "//",
      json = "//",
      cff = "#",
      nix = "#", 
    }
    if filename:match("^LICENSE") then
      table.insert(header, "Copyright (C) 2025 Qompass AI, All rights reserved")
      table.insert(header, "")
    else
      if (filetype == "markdown") or (ext == "md") or (filename:lower():match("^readme%.md$")) then
        comment = "<!--"
      elseif comment_map[filetype] then
        comment = comment_map[filetype]
      elseif ext == "mojo" or ext == "🔥" then
        comment = "#"
      elseif ext == "zig" then
        comment = "//"
      elseif ext == "html" then
        comment = "<!--"
      elseif ext == "css" then
        comment = "/*"
      elseif ext == "yaml" or ext == "yml" or ext == "cf" or ext == "cfn" then
        comment = "#"
      elseif ext == "py" then
        comment = "#"
      elseif ext == "go" then
        comment = "//"
      elseif ext == "ts" then
        comment = "//"
      elseif ext == "js" then
        comment = "//"
      elseif ext == "json" then
        comment = "//"
      elseif ext == "cff" then
        comment = "#"
      elseif ext == "nix" then
        comment = "#"
      end
      local filepath = vim.fn.expand("%:~")
      if comment == "<!--" then
        table.insert(header, string.format("<!-- %s -->", filepath))
        table.insert(header, string.format("<!-- %s -->", string.rep("-", #filepath)))
        table.insert(header, "<!-- Copyright (C) 2025 Qompass AI, All rights reserved -->")
        table.insert(header, "")
      elseif comment == "/*" then
        table.insert(header, string.format("/* %s */", filepath))
        table.insert(header, string.format("/* %s */", string.rep("-", #filepath)))
        table.insert(header, "/* Copyright (C) 2025 Qompass AI, All rights reserved */")
        table.insert(header, "")
      else
        table.insert(header, string.format("%s %s", comment, filepath))
        table.insert(header, string.format("%s %s", comment, string.rep("-", #filepath)))
        table.insert(header, string.format("%s Copyright (C) 2025 Qompass AI, All rights reserved", comment))
        table.insert(header, "")
      end
    end
    if vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "" then
      vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
      vim.cmd("normal! G")
    end
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = augroups.markdown,
  pattern = { "markdown", "md" },
  callback = function()
    vim.g.mkdp_auto_start = 0
    vim.g.mkdp_auto_close = 1
    vim.g.mkdp_refresh_slow = 0
    vim.g.mkdp_command_for_global = 0
    vim.g.mkdp_open_to_the_world = 0
    vim.g.mkdp_open_ip = "127.0.0.1"
    vim.g.mkdp_browser = ""
    vim.g.mkdp_echo_preview_url = 1
    vim.g.mkdp_page_title = "${name}"
    vim.g.mkdp_filetypes = { "markdown" }
    vim.g.mkdp_markdown_css = ""
    vim.g.vim_markdown_folding_disabled = 1
    vim.g.vim_markdown_math = 1
    vim.g.vim_markdown_frontmatter = 1
    vim.g.vim_markdown_toml_frontmatter = 1
    vim.g.vim_markdown_json_frontmatter = 1
    vim.g.vim_markdown_follow_anchor = 1
    vim.opt_local.wrap = true
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = "nc"
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
    vim.opt_local.textwidth = 80
  end,
})
if has_011 then
  vim.api.nvim_create_autocmd("CursorHold", {
    group = augroups.diagnostics,
    callback = function()
      vim.diagnostic.open_float(nil, {
        focusable = false,
        close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
        scope = "cursor",
      })
    end,
  })
end
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = {"Dockerfile.*", "*.Dockerfile", "Containerfile", "*.containerfile"},
  callback = function()
    vim.bo.filetype = "dockerfile"
  end,
})
-- Zig
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = {"*.zig", "*.zon"},
  callback = function()
    vim.lsp.buf.format()
  end,
})
return M
