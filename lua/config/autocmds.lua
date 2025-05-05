-----------------------|  Ansible |-------------------------------

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  pattern = {
    "*/playbooks/*.yml",
    "*/tasks/*.yml",
    "*/roles/*.yml",
    "*/handlers/*.yml",
    "*/ansible/*.yml",
  },
  callback = function()
    vim.bo.filetype = "ansible"
  end,
})

-----------------------|   JSON    |-------------------------------

vim.api.nvim_create_autocmd('LspAttach', {
  desc = 'Enable enhanced LSP completion',
  callback = function(event)
    local client_id = vim.tbl_get(event, 'data', 'client_id')
    if client_id == nil then return end
    
    if vim.fn.has('nvim-0.11') == 1 then
      vim.lsp.completion.enable(true, client_id, event.buf, {autotrigger = true})
    end
  end
})

vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
  pattern = { "*.json", "*.jsonc" },
  callback = function()
    vim.lsp.buf.document_highlight()
    vim.diagnostic.reset()
    vim.lsp.buf.semantic_tokens_refresh()
  end,
})

-----------------------| Lazy |---------------------------------

vim.api.nvim_create_autocmd("User", {
  pattern = "LazyCheck",
  desc = "Update lazy.nvim plugins",
  callback = function()
    require('lazy').sync({ wait = false, show = true })
  end,
})

-----------------------|   Lua    |-------------------------------
vim.api.nvim_create_autocmd("FileType", {
  pattern = "lua",
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.expandtab = true
  end,
})

-----------------------| Rust | ------------------------------

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.rs",
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  callback = function()
    require("mappings.rustmap").setup()
  end,
})
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = "Cargo.toml",
  callback = function()
    vim.bo.filetype = "toml"
  end
})
local cargo_cmds = {
  { "CargoTest",         "test",                                  "Run cargo tests" },
  { "CargoDoc",          "doc --open",                            "Generate and open documentation" },
  { "CargoBuildAndroid", "build --target aarch64-linux-android",  "Build for Android" },
  { "CargoBuildIos",     "build --target aarch64-apple-ios",      "Build for iOS" },
  { "CargoBuildWasm",    "build --target wasm32-unknown-unknown", "Build for WASM" },
}
for _, cmd in ipairs(cargo_cmds) do
  vim.api.nvim_create_user_command(cmd[1], function()
    vim.cmd("!cargo " .. cmd[2])
  end, { desc = cmd[3] })
end
vim.api.nvim_create_user_command("CargoExpand", function()
  vim.cmd("!cargo expand")
end, { desc = "Expand macros in Rust source" })
vim.api.nvim_create_user_command("CargoNextest", function()
  vim.cmd("!cargo nextest run")
end, { desc = "Run tests with cargo-nextest" })
vim.api.nvim_create_user_command("CargoZigBuild", function()
  vim.cmd("!cargo zigbuild --target aarch64-unknown-linux-gnu")
end, { desc = "Zig cross compile for aarch64-linux-gnu" })
vim.api.nvim_create_user_command("CargoAudit", function()
  vim.cmd("!cargo audit")
end, { desc = "Audit Cargo.lock for vulnerabilities" })
vim.api.nvim_create_user_command("CargoWatch", function()
  vim.cmd("!cargo watch -x run")
end, { desc = "Watch and run app on file changes" })
vim.api.nvim_create_user_command("CargoBloat", function()
  vim.cmd("!cargo bloat --crates")
end, { desc = "Show crate-level binary bloat" })
vim.api.nvim_create_user_command("CargoCoverageOpen", function()
  vim.cmd("!xdg-open tarpaulin-report.html")
end, { desc = "Open last tarpaulin coverage report" })
vim.api.nvim_create_user_command("CargoFlamegraph", function()
  vim.cmd("!cargo flamegraph")
end, { desc = "Generate flamegraph for current project" })
vim.api.nvim_create_user_command("LeptosBuild", function()
  vim.cmd("!cargo leptos build --release")
end, { desc = "Build Leptos frontend" })
vim.api.nvim_create_user_command("PingoraRun", function()
  vim.cmd("!sudo cargo run")
end, { desc = "Run Pingora with elevated privileges" })
vim.api.nvim_create_user_command("TrunkServe", function()
  vim.cmd("!trunk serve")
end, { desc = "Serve via trunk (WASM/web)" })
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "Dockerfile.*", "*.Dockerfile", "Containerfile", "*.containerfile" },
  callback = function()
    vim.bo.filetype = "dockerfile"
  end,
})

------------------------ | Discord |-------------------------------
vim.filetype.add({
  pattern = {
    [".*/waybar/config"] = "jsonc",
    [".*/hypr/.*%.conf"] = "hyprlang",
  },
})

--vim.keymap.set("n", "<leader>cf", function()
--  require("conform").format({
--   lsp_format = "fallback",
--    async = true,
--    timeout_ms = 500,
--  })
--end, { desc = "Format buffer" })

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.nginx", "nginx.conf", "/etc/nginx/**/*.conf" },
  callback = function()
    vim.bo.filetype = "nginx"
  end,
})

------------------------ | Python |-------------------------------

vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.autoindent = true
    vim.opt_local.smartindent = true
  end,
})

local pytest_cmd = "pytest"
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.api.nvim_buf_create_user_command(0, "PythonLint", function()
      vim.lsp.buf.format()
      vim.cmd("write")
      vim.notify("Python code linted and formatted", vim.log.levels.INFO)
    end, {})
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    local function run_pytest_file()
      local file = vim.fn.expand("%:p")
      vim.cmd("split | terminal " .. pytest_cmd .. " " .. file)
    end

    local function run_pytest_function()
      local file = vim.fn.expand("%:p")
      local cmd = pytest_cmd .. " " .. file .. "::" .. vim.fn.expand("<cword>") .. " -v"
      vim.cmd("split | terminal " .. cmd)
    end

    vim.api.nvim_buf_create_user_command(0, "PyTestFile", run_pytest_file, {})
    vim.api.nvim_buf_create_user_command(0, "PyTestFunc", run_pytest_function, {})
  end,
})

-------------------------| Scala  |--------------------------------

------------------------| MasonTools|------------------------------

vim.api.nvim_create_autocmd("User", {
  pattern = "MasonToolsStartingInstall",
  callback = function()
    vim.schedule(function()
      print("mason-tool-installer is starting")
    end)
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "MasonToolsUpdateCompleted",
  callback = function(e)
    vim.schedule(function()
      print(vim.inspect(e.data))
    end)
  end,
})
-------------------------| Markdown  |--------------------------------
local markdown_group = vim.api.nvim_create_augroup("MarkdownSettings", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = markdown_group,
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
    vim.g.vim_markdown_anchorexpr = "v:lua.require'config.ui.markdown'.get_anchor(v:fname)"
    vim.opt_local.wrap = true
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = "nc"
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
    vim.opt_local.textwidth = 80
  end,
})

-----------------------| Qompass  |-------------------------------

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
      json = "//",      -- Not official
      cff = "#",
    }

    -- Special handling for LICENSE files (no comment, just copyright)
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

-----------------------| Teaching |-------------------------------

vim.api.nvim_create_autocmd({ "CursorHold" }, {
  callback = function()
    vim.diagnostic.open_float(nil, {
      focusable = false,
      close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
      scope = "cursor",
    })
  end,
})

-----------------------| YAML |-------------------------------

vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = {"*.yml", "*.yaml"},
  callback = function()
    local content = vim.api.nvim_buf_get_lines(0, 0, 30, false)
    local content_str = table.concat(content, "\n")

    if content_str:match("ansible_") or (content_str:match("hosts:") and content_str:match("tasks:")) then
      vim.bo.filetype = "yaml.ansible"
    elseif content_str:match("apiVersion:") and content_str:match("kind:") then
      vim.bo.filetype = "yaml.kubernetes"
    elseif content_str:match("version:") and content_str:match("services:") then
      vim.bo.filetype = "yaml.docker"
    end
  end
})

------------------------| Zig |-------------------------------
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = {"*.zig", "*.zon"},
  callback = function()
    vim.lsp.buf.format()
  end
})

