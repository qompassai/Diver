-- ~/.config/nvim/lua/cicd/shell.lua
-- ------------------------------------
local M = {}
local bit = require("bit")

function M.setup_sh_completion(opts)
  local sources = opts.sources or {}
  table.insert(sources, {
    name = "blink",
    group_index = 1,
    priority = 100,
    option = {
      additional_trigger_characters = { "-", "/", "$" },
    },
    entry_filter = function(entry, ctx)
      local ft = ctx.filetype
      return ft == "sh" or ft == "bash" or ft == "zsh" or ft == "fish" or ft == "nu"
    end,
  })
  opts.sources = sources
  return opts
end

function M.setup_sh_lsp(opts)
  opts.servers = opts.servers or {}

  opts.servers.bashls = {
    filetypes = { "sh", "bash" },
    settings = {
      bashIde = {
        globPattern = "*@(.sh|.bash|.inc|.command)",
        backgroundAnalysisMaxFiles = 500,
        enableSourceErrorDiagnostics = true,
      },
    },
  }

  opts.servers.fish_ls = {
    filetypes = { "fish" },
  }

  opts.servers.nushell = {
    filetypes = { "nu" },
  }

  return opts
end

function M.setup_sh_linter(opts)
  local null_ls = require("null-ls")
  local shellcheck = require("none-ls-shellcheck")

  opts.sources = vim.list_extend(opts.sources or {}, {
    shellcheck.diagnostics,
    null_ls.builtins.diagnostics.fish,
    null_ls.builtins.diagnostics.zsh,
    shellcheck.code_actions,
  })

  opts.root_dir = M.detect_sh_root_dir

  return opts
end

function M.setup_sh_conform(opts)
  opts.formatters_by_ft = opts.formatters_by_ft or {}
  opts.formatters_by_ft.sh = { "shfmt", "beautysh" }

  opts.formatters = vim.tbl_deep_extend("force", opts.formatters or {}, {
    shfmt = vim.fn.executable("shfmt") == 1 and {
      command = "shfmt",
      args = { "-i", "2", "-ci", "-" },
      stdin = true,
    } or nil,

    beautysh = vim.fn.executable("beautysh") == 1 and {
      command = "beautysh",
      args = {},
      stdin = true,
      condition = function(ctx)
        local stat = vim.loop.fs_stat(ctx.filename)
        return stat and stat.type == "file" and bit.band(stat.mode, 73) ~= 0
      end,
    } or nil,
  })

  return opts
end

function M.setup_sh_formatter(opts)
  local null_ls = require("null-ls")
  opts.sources = vim.list_extend(opts.sources or {}, {
    null_ls.builtins.formatting.shfmt,
    null_ls.builtins.formatting.beautysh,
    null_ls.builtins.formatting.fish_indent,
  })
  return opts
end

function M.detect_sh_root_dir(fname)
  local util = require("lspconfig.util")
  local root = util.root_pattern(".git")(fname)

  local stat = vim.loop.fs_stat(fname)
  if not stat or stat.type ~= "file" then
    return root
  end

  local file = io.open(fname, "r")
  if file then
    local first_line = file:read()
    file:close()
    if
      first_line
      and (
        first_line:match("^#!.*sh")
        or first_line:match("^#!.*zsh")
        or first_line:match("^#!.*fish")
        or first_line:match("^#!.*nu")
      )
    then
      return root or vim.fn.getcwd()
    end
  end

  return root
end

function M.setup_sh_filetype_detection()
  vim.filetype.add({
    extension = {
      sh = "bash",
      bash = "bash",
      zsh = "zsh",
      fish = "fish",
      nu = "nu",
    },
    pattern = {
      [".*.sh"] = "bash",
      [".*.bash"] = "bash",
      [".bash*"] = "bash",
      [".*.zsh"] = "zsh",
      [".zsh*"] = "zsh",
      [".*.fish"] = "fish",
      [".*.nu"] = "nu",
    },
    filename = {
      [".bashrc"] = "bash",
      [".zshrc"] = "zsh",
      ["config.fish"] = "fish",
    },
  })
end

function M.setup_sh_keymaps(opts)
  opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
    ["<leader>cs"] = { name = "+shell" },
    ["<leader>csf"] = { "<cmd>lua require('conform').format()<cr>", "Format Shell Script" },
    ["<leader>csc"] = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Shell Code Actions" },
    ["<leader>csl"] = { "<cmd>TroubleToggle lsp_document_diagnostics<cr>", "Shell Lint Issues" },
  })
  return opts
end

return M
