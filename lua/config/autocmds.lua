-- ~/.config/nvim/lua/config/autocmds.lua
local M = {}
local has_011 = vim.fn.has("nvim-0.11") == 1
local augroups = {
  ansible = vim.api.nvim_create_augroup("AnsibleFT", { clear = true }),
  diagnostics = vim.api.nvim_create_augroup("Diagnostics", { clear = true }),
  json = vim.api.nvim_create_augroup("JSON", { clear = true }),
  lint = vim.api.nvim_create_augroup("nvim_lint", { clear = true }),
  lsp = vim.api.nvim_create_augroup("LSP", { clear = true }),
  markdown = vim.api.nvim_create_augroup("MarkdownSettings", { clear = true }),
  mason = vim.api.nvim_create_augroup("Mason", { clear = true }),
  python = vim.api.nvim_create_augroup("Python", { clear = true }),
  rust = vim.api.nvim_create_augroup("Rust", { clear = true }),
  yaml = vim.api.nvim_create_augroup("YAML", { clear = true }),
  zig = vim.api.nvim_create_augroup("Zig", { clear = true }),
}
M.setup_filetype_detection = function()
  if vim.filetype and vim.filetype.add then
    vim.filetype.add({
      pattern = {
        ["*.🔥"] = "mojo",
        ["*/ansible/*.yml"] = "ansible",
        ["Cargo.toml"] = "toml",
        ["*.containerfile"] = "dockerfile",
        ["Containerfile"] = "dockerfile",
        ["Dockerfile.*"] = "dockerfile",
        ["*.Dockerfile"] = "dockerfile",
        ["*/handlers/*.yml"] = "ansible",
        [".*/hypr/.*%.conf"] = "hyprlang",
        ["*.mojo"] = "mojo",
        ["*.nginx"] = "nginx",
        ["nginx.conf"] = "nginx",
        ["*/playbooks/*.yml"] = "ansible",
        ["*/roles/*.yml"] = "ansible",
        ["*/tasks/*.yml"] = "ansible",
        [".*/waybar/config"] = "jsonc",
        ["/etc/nginx/**/*.conf"] = "nginx",
        ["*.zig"] = "zig",
        ["*.zon"] = "zig",
      },
    })
  end
end
vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
  group = augroups.json,
  pattern = { "*.json", "*.jsonc" },
  callback = function()
    vim.diagnostic.reset()
    if vim.lsp.buf.document_highlight then
      vim.lsp.buf.document_highlight()
    end
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
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
    local ok, rustmap = pcall(require, "mappings.rustmap")
    if ok and rustmap and type(rustmap.setup) == "function" then
      rustmap.setup()
    end
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
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = augroups.ansible,
  pattern = {
    "*/ansible/*.yml",
    "*/playbooks/*.yml",
    "*/tasks/*.yml",
    "*/roles/*.yml",
    "*/handlers/*.yml",
  },
  callback = function()
    vim.bo.filetype = "ansible"
  end,
})
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = augroups.yaml,
  pattern = { "*.yml", "*.yaml" },
  callback = function()
    local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, 30, false), "\n")
    if content:match("ansible_") or (content:match("hosts:") and content:match("tasks:")) then
      vim.bo.filetype = "yaml.ansible"
    elseif content:match("apiVersion:") and content:match("kind:") then
      vim.bo.filetype = "yaml.kubernetes"
    elseif content:match("version:") and content:match("services:") then
      vim.bo.filetype = "yaml.docker"
    end
  end,
})
vim.api.nvim_create_autocmd("BufNewFile", {
  pattern = "*",
  callback = function()
    local filename = vim.fn.expand("%:t")
    local filepath = vim.fn.expand("%:~")
    local ext = vim.fn.expand("%:e")
    local filetype = vim.bo.filetype
    local header = {}
    local comment_map = {
      arduino = "//",
      asciidoc = "//",
      asm = ";",
      astro = "//",
      avro = "#",
      bash = "#",
      bicep = "//",
      c = "//",
      cf = "#",
      cff = "#",
      cfn = "#",
      clojure = ";",
      cmake = "#",
      compute = "//",
      conf = "#",
      cpp = "//",
      cs = "//",
      css = "/*",
      cuda = "//",
      cue = "//",
      dhall = "--",
      dockerfile = "#",
      dosini = ";",
      elixir = "#",
      fish = "#",
      fix = "#",
      glsl = "//",
      go = "//",
      graphql = "#",
      h = "//",
      haskell = "--",
      hlsl = "//",
      hocon = "#",
      hpp = "//",
      html = "<!--",
      ini = ";",
      java = "//",
      javascript = "//",
      javascriptreact = "//",
      js = "//",
      json = "//",
      jsonc = "//",
      julia = "#",
      kotlin = "//",
      latex = "%",
      less = "/*",
      lua = "--",
      markdown = "<!--",
      md = "<!--",
      mdx = "//",
      meson = "#",
      mlir = "//",
      mojo = "#",
      mql4 = "//",
      mql5 = "//",
      nix = "#",
      opencl = "//",
      openqasm = "//",
      parquet = "#",
      perl = "#",
      php = "//",
      pine = "//",
      pl = "#",
      plsql = "--",
      powershell = "#",
      proto = "//",
      protobuf = "//",
      py = "#",
      python = "#",
      qsharp = "//",
      quil = "#",
      r = "#",
      rb = "#",
      renderdoc = "#",
      rmd = "#",
      rs = "//",
      rst = "..",
      ruby = "#",
      rust = "//",
      sass = "//",
      scala = "//",
      scss = "/*",
      sh = "#",
      sql = "--",
      svelte = "//",
      swift = "//",
      systemverilog = "//",
      terraform = "#",
      tex = "%",
      toml = "#",
      ts = "//",
      typescript = "//",
      typescriptreact = "//",
      unity = "//",
      verilog = "//",
      vhdl = "--",
      vim = '"',
      vue = "//",
      wasm = ";;",
      wat = ";;",
      x86asm = ";",
      xml = "<!--",
      yaml = "#",
      yml = "#",
      zig = "//",
      zsh = "#",
    }
    local comment
    if filename:match("^LICENSE") then
      table.insert(header, "Copyright (C) 2025 Qompass AI, All rights reserved")
      table.insert(header, "")
    else
      comment = comment_map[ext] or comment_map[filetype] or "#"
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
        close_events = {
          "BufLeave",
          "CursorMoved",
          "InsertEnter",
          "FocusLost",
        },
        scope = "cursor",
      })
    end,
  })
end
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = {
    "Dockerfile.*",
    "*.Dockerfile",
    "Containerfile",
    "*.containerfile",
  },
  callback = function()
    vim.bo.filetype = "dockerfile"
  end,
})
vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
  group = augroups.lint,
  callback = function()
    vim.defer_fn(function()
      local lint_status, lint = pcall(require, "lint")
      if lint_status then
        lint.try_lint()
      end
    end, 100)
  end,
})
vim.api.nvim_create_autocmd("BufWritePost", {
  group = augroups.lint,
  callback = function()
    local filepath = vim.fn.expand("%:p")
    local filename = vim.fn.expand("%:t"):lower()
    local extension = vim.fn.expand("%:e"):lower()
    local ft = vim.bo.filetype
    local lint_status, lint = pcall(require, "lint")
    if not lint_status then
      return
    end
    if filepath:match(".github/workflows") and (extension == "yml" or extension == "yaml") then
      lint.try_lint("actionlint")
    end
    if
      filepath:match("secret")
      or filepath:match("password")
      or filepath:match("key")
      or filepath:match("token")
      or filepath:match("credential")
    then
      lint.try_lint("bandit")
    end
    lint.try_lint("codespell")
    if filepath:match("/etc/nixos/") or extension == "nix" then
      lint.try_lint({ "deadnix", "statix" })
    end
    local patterns = {
      "dockerfile",
      "containerfile",
      "compose%.yml$",
      "compose%.yaml$",
      "docker%-compose",
    }
    if filename:lower():match(table.concat(patterns, "|")) then
      lint.try_lint({ "hadolint", "dockerfilelint" })
    end
    if lint.linters_by_ft[ft] then
      lint.try_lint(lint.linters_by_ft[ft])
    end
    if ft == "verilog" or ft == "vhdl" or ft == "systemverilog" then
      lint.try_lint("verilator")
    end
    if extension == "mojo" or ft == "mojo" or filename:match("%.🔥$") then
      lint.try_lint("mojo-check")
    end
    if extension == "sql" then
      lint.try_lint("sqlfluff")
    end
    if extension == "tf" or extension == "tfvars" then
      lint.try_lint({ "tflint", "tfsec" })
    end
    if extension == "wat" or extension == "wasm" then
      lint.try_lint({ "wasm-validate", "wat2wasm" })
    end
    if not lint.linters_by_ft[ft] and lint.linters_by_ft[extension] then
      lint.try_lint(lint.linters_by_ft[extension])
    end
  end,
})
vim.api.nvim_create_autocmd("LspAttach", {
  group = augroups.lint,
  callback = function()
    local lint_status, lint = pcall(require, "lint")
    if lint_status then
      lint.try_lint()
    end
  end,
})
M.setup_mason_autocmds = function()
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    group = augroups.json,
    pattern = { "*.json", "*.jsonc", "*.json5", "*.jsonl" },
    callback = function()
      if vim.lsp.buf.document_highlight then
        vim.lsp.buf.document_highlight()
      end
      vim.diagnostic.reset()
      local semantic_token_refresh = function()
        local refresh_func
        if vim.lsp.buf.semantic_tokens_refresh then
          refresh_func = vim.lsp.buf.semantic_tokens_refresh
        elseif vim.lsp.semantic_tokens and vim.lsp.semantic_tokens.refresh then
          refresh_func = vim.lsp.semantic_tokens.refresh
        end
        if refresh_func then
          pcall(refresh_func)
        end
      end
      semantic_token_refresh()
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = augroups.mason,
    pattern = "MasonInstallComplete",
    callback = function(args)
      local package_name = args.data.package.name
      vim.notify(string.format("✅ Mason installed: %s", package_name), vim.log.levels.INFO)
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = augroups.mason,
    pattern = "MasonUpdateComplete",
    callback = function(args)
      local package_name = args.data.package.name
      vim.notify(string.format("🔄 Mason updated: %s", package_name), vim.log.levels.INFO)
    end,
  })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = augroups.lsp,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then
        vim.notify(string.format("LSP attached: %s", client.name), vim.log.levels.DEBUG)
      end
    end,
  })
  vim.api.nvim_create_autocmd("LspDetach", {
    group = augroups.lsp,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then
        vim.notify(string.format("LSP detached: %s", client.name), vim.log.levels.DEBUG)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroups.mason,
    once = true,
    callback = function()
      if vim.env.CARGO_TARGET_DIR then
        vim.notify("🦀 Cargo optimization enabled for Mason", vim.log.levels.DEBUG)
      end
    end,
  })
end
return M
