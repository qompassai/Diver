-- ~/.config/nvim/lua/config/zig.lua
local M = {}

function M.zig_settings(opts)
  opts = opts or {}
  return {
    format_on_save = opts.format_on_save or true,
    build_on_save = opts.build_on_save or true,
    fmt_autosave = opts.fmt_autosave or false,
    fmt_parse_errors = opts.fmt_parse_errors or false,
  }
end

function M.zig_tools(opts)
  opts = opts or {}
  return {
    autocmds = {
      format_on_save = false,  -- We use LSP for formatting
      build_on_save = true,
    },
    zls = {
      enabled = true,
      config_dir = vim.fn.stdpath("config") .. "/lua/config/zls.json",
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
      return require("lspconfig").util.root_pattern("zls.json", "build.zig", ".git")(fname)
    end,
    settings = {
      zls = {
        semantic_tokens = "partial",
        enable_build_on_save = opts.enable_build_on_save or false,
      },
    },
  }
end

function M.setup_all(opts)
  opts = opts or {}

  -- Initialize Zig.vim settings
  vim.g.zig_fmt_autosave = 0
  vim.g.zig_fmt_parse_errors = 0

  -- Set up keymaps if which-key is available
  local wk_ok, wk = pcall(require, "which-key")
  if wk_ok then
    wk.register({
      ["<leader>Z"] = {
        name = "+zig",
        b = { "<cmd>ZigBuild<CR>", "Build" },
        r = { "<cmd>ZigRun<CR>", "Run" },
        t = { "<cmd>ZigTest<CR>", "Test" },
        d = { "<cmd>ZigToggleBuildMode<CR>", "Toggle Build Mode" },
        f = { "<cmd>ZigFmt<CR>", "Format" },
        c = { "<cmd>Telescope zig<CR>", "Zig Commands" },
        e = { function() require("dap").continue() end, "Debug" },
        n = { "<cmd>TestNearest<CR>", "Test Nearest" },
        a = { "<cmd>TestFile<CR>", "Test File" },
      },
    })
  end

  -- Return the complete configuration
  return {
    settings = M.zig_settings(opts),
    tools = M.zig_tools(opts),
    lsp = M.zig_lsp(opts),
  }
end

return M

