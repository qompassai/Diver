-- ~/.config/nvim/lua/config/zig.lua
local M = {}
local function find_executable(names)
  local paths = {
    vim.env.HOME .. "/.local/bin/",
    vim.fn.stdpath("data") .. "/mason/bin/",
    "",
  }
  for _, name in ipairs(names) do
    for _, path in ipairs(paths) do
      local full_path = path .. name
      if vim.fn.executable(full_path) == 1 then
        return full_path
      end
    end
  end
  return nil
end
local zls_path = find_executable({ "zls" }) or "zls"
local zig_path = find_executable({ "zig" }) or "zig"
if not vim.fn.executable(zls_path) then
  vim.notify("ZLS not found in PATH or local directories. Install with :MasonInstall zls", vim.log.levels.WARN)
end
require("lspconfig").zls.setup({
  cmd = { zls_path },
  settings = {
    zls = {
      enable_ast_check_diagnostics = true,
      enable_build_on_save = true,
      build_on_save_step = "check",
      semantic_tokens = "full",
      enable_snippets = true,
      operator_completions = true,
      include_at_in_builtins = true,
      enable_inlay_hints = true,
      inlay_hints = {
        parameter_names = true,
        variable_names = false,
        builtin = true,
        type_names = true,
      },
      enable_import_embedfile_argument_completions = true,
      warn_style = true,
      skip_std_references = false,
      zig_exe_path = zig_path,
      zig_lib_path = vim.env.HOME .. "/.local/lib/zig",
    },
  },
  init_options = {
    build_runner_path = "build_runner.zig",
    global_cache_path = vim.fn.stdpath("cache") .. "/zls",
  },
  on_attach = function(_client, bufnr)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = "Zig: " .. desc })
    end
    map("n", "gd", vim.lsp.buf.definition, "Goto Definition")
    map("n", "K", vim.lsp.buf.hover, "Hover Documentation")
    map("n", "<leader>zih", function()
      vim.lsp.inlay_hint.enable(bufnr, not vim.lsp.inlay_hint.is_enabled(bufnr))
    end, "Toggle Inlay Hints")
  end,
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
})
local zlint_path = find_executable({ "zlint" })
if zlint_path then
  require("lint").linters.zlint = {
    cmd = zlint_path,
    args = { "--format", "github" },
    stdin = false,
    stream = "stdout",
    ignore_exitcode = true,
    parser = function(output)
  local diagnostics = {}
  for _, line in ipairs(vim.split(output, "\n")) do
    local line_num, col_num, code, msg = line:match(":(%d+):(%d+): (%S+): (.*)")
    if line_num and col_num then
      table.insert(diagnostics, {
        lnum = tonumber(line_num) - 1,
        col = tonumber(col_num) - 1,
        message = string.format("[%s] %s", code, msg),
        severity = vim.diagnostic.severity.WARN,
        source = "zlint",
      })
    end
  end
  return diagnostics
end,
  }
else
  vim.notify("Zlint not found. Install to ~/.local/bin/zlint for enhanced linting", vim.log.levels.INFO)
end
function M.zig_settings(opts)
  opts = opts or {}
  return {
    format_on_save = opts.format_on_save or true,
    build_on_save = opts.build_on_save or true,
    fmt_autosave = opts.fmt_autosave or false,
    fmt_parse_errors = opts.fmt_parse_errors or false,
  }
end
function M.zig_tools()
  return {
    autocmds = {
      format_on_save = false,
      build_on_save = true,
    },
    zls = {
      enabled = true,
    },
    build = {
      build_dir = "zig-out",
    },
  }
end
function M.zig_lsp(opts)
  opts = opts or {}
  return {
    filetypes = { "zig", "zon" },
    root_dir = function(fname)
      return require("lspconfig.util").root_pattern("zls.json", "build.zig", ".git")(fname)
    end,
    settings = {
      zls = {
        semantic_tokens = "full",
        enable_build_on_save = opts.enable_build_on_save or true,
      },
    },
  }
end
function M.setup_zig()
  vim.g.zig_fmt_autosave = 0
  vim.g.zig_fmt_parse_errors = 0
  local wk_ok, wk = pcall(require, "which-key")
  if wk_ok then
    wk.register({
      ["<leader>Z"] = { name = "+zig" },
      ["<leader>Za"] = { "<cmd>TestFile<CR>", "Test File" },
      ["<leader>Zb"] = { "<cmd>ZigBuild<CR>", "Build" },
      ["<leader>Zc"] = { "<cmd>Telescope zig<CR>", "Zig Commands" },
      ["<leader>Zd"] = { "<cmd>ZigToggleBuildMode<CR>", "Toggle Build Mode" },
      ["<leader>Ze"] = { function() require("dap").continue() end, "Debug" },
      ["<leader>Zf"] = { "<cmd>ZigFmt<CR>", "Format" },
      ["<leader>Zl"] = { "<cmd>LspRestart<CR>", "Restart LSP" },
      ["<leader>Zn"] = { "<cmd>TestNearest<CR>", "Test Nearest" },
      ["<leader>Zr"] = { "<cmd>ZigRun<CR>", "Run" },
      ["<leader>Zt"] = { "<cmd>ZigTest<CR>", "Test" },
    })
  end
  vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    pattern = { "*.zig", "*.zon" },
    callback = function()
      if zlint_path then
        require("lint").try_lint("zlint")
      end
    end,
  })
  return {
    settings = M.zig_settings(opts),
    tools = M.zig_tools(),
    lsp = M.zig_lsp(opts),
  }
end
return M
