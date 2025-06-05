-- ~/.config/nvim/lua/data/sqlite.lua
-------------------------------------
local common = require("config.data.common")
local M = {}
function M.setup_conform(opts)
  opts.formatters_by_ft =
    vim.tbl_deep_extend("force", opts.formatters_by_ft or {}, { sqlite = { "sqlfluff", "sql-formatter" } })

  opts.formatters = vim.tbl_deep_extend("force", opts.formatters or {}, {
    sqlfluff = {
      args = { "fix", "--dialect", "sqlite", "-" },
      stdin = true,
    },
    ["sql-formatter"] = {
      args = { "--language", "sqlite" },
    },
  })

  return opts
end
function M.setup_lsp(opts)
  if not opts.servers then
    opts.servers = {}
  end
  opts.servers.sqlls = vim.tbl_deep_extend("force", opts.servers.sqlls or {}, {
    autostart = true,
    filetypes = { "sqlite" },
    root_dir = common.detect_sql_root_dir,
    settings = {
      sqlLanguageServer = {
        dialect = "sqlite",
      },
    },
  })
  return opts
end

function M.setup_linter(opts)
  local null_ls = require("null-ls")

  opts.sources = vim.list_extend(opts.sources or {}, {
    null_ls.builtins.diagnostics.sqlfluff.with({
      filetypes = { "sqlite" },
      extra_args = { "--dialect", "sqlite" },
    }),
  })

  return opts
end

function M.setup_formatter(opts)
  local null_ls = require("null-ls")

  opts.sources = vim.list_extend(opts.sources or {}, {
    null_ls.builtins.formatting.sqlfluff.with({
      filetypes = { "sqlite" },
      extra_args = { "--dialect", "sqlite" },
    }),
    null_ls.builtins.formatting.sql_formatter.with({
      filetypes = { "sqlite" },
      extra_args = { "--language", "sqlite" },
    }),
  })

  return opts
end
function M.setup_filetype_detection()
  vim.filetype.add({
    extension = {
      sqlite = "sqlite",
      sqlite3 = "sqlite",
      db = "sqlite",
    },
    pattern = {
      ["%.lite%.sql$"] = "sqlite",
      ["%.sqlite%.sql$"] = "sqlite",
    },
  })
end
function M.setup_keymaps(opts)
  opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
    ["<leader>ds"] = { name = "+sqlite" },
    ["<leader>dsf"] = { "<cmd>lua require('conform').format()<cr>", "Format SQLite" },
    ["<leader>dst"] = { "<cmd>DBUIToggle<cr>", "Toggle DBUI" },
    ["<leader>dsa"] = { "<cmd>DBUIAddConnection<cr>", "Add Connection" },
    ["<leader>dsh"] = { "<cmd>DBUIFindBuffer<cr>", "Find DB Buffer" },
    ["<leader>dse"] = {
      function()
        if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
          vim.cmd("'<,'>DB")
        else
          vim.cmd("DB")
        end
      end,
      "Execute Query",
    },

    ["<leader>dsst"] = { "<cmd>DB SELECT name FROM sqlite_master WHERE type='table'<cr>", "List Tables" },
    ["<leader>dssi"] = { "<cmd>DB SELECT * FROM sqlite_master WHERE type='index'<cr>", "List Indexes" },
    ["<leader>dssv"] = { "<cmd>DB PRAGMA schema_version<cr>", "Schema Version" },
  })
  return opts
end
return M
