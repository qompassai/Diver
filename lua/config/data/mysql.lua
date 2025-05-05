-- ~/.config/nvim/lua/data/mysql.lua
------------------------------------
local common = require("config.data.common")
local M = {}
function M.setup_completion(opts)
  opts.fuzzy = opts.fuzzy or {}
  opts.fuzzy.implementation = "lua" -- "prefer_rust" or "lua"
  
    opts.sources = {
      default = { "lsp", "path", "snippets", "buffer" },
      per_filetype = {}
    }
  end
  
  opts.sources.per_filetype = opts.sources.per_filetype or {}
  opts.sources.per_filetype.mysql = {
    "vim-dadbod-completion",
    "snippets",
    "lsp",
    "path",
    "buffer"
  }
  local blink_source = {
    name = "blink",
    group_index = 1,
    priority = 100,
    option = {
      additional_trigger_characters = { ".", ",", "(", ":" },
    },
    entry_filter = function(entry, ctx)
      return ctx.filetype == "mysql"
    end
  }
  if type(opts.sources) == "table" and opts.sources[1] then
    table.insert(opts.sources, blink_source)
  end
  
  return opts
end
function M.setup_conform(opts)
  opts.formatters_by_ft = vim.tbl_deep_extend("force",
    opts.formatters_by_ft or {},
    { mysql = { "sqlfluff", "sql-formatter" } }
  )

  opts.formatters = vim.tbl_deep_extend("force",
    opts.formatters or {},
    {
      sqlfluff = {
        args = { "fix", "--dialect", "mysql", "-" },
        stdin = true,
      },
      ["sql-formatter"] = {
        args = { "--language", "mysql" },
      }
    }
  )
  return opts
end
function M.setup_lsp(opts)
  if not opts.servers then opts.servers = {} end
  opts.servers.sqlls = vim.tbl_deep_extend("force",
    opts.servers.sqlls or {},
    {
      autostart = true,
      filetypes = { "mysql" },
      root_dir = common.detect_sql_root_dir,
      settings = {
        sqlLanguageServer = {
          dialect = "mysql"
        }
      }
    }
  )
  return opts
end
function M.setup_linter(opts)
  local null_ls = require("null-ls")
  opts.sources = vim.list_extend(opts.sources or {}, {
    null_ls.builtins.diagnostics.sqlfluff.with({
      filetypes = { "mysql" },
      extra_args = { "--dialect", "mysql" },
    }),
  })

  return opts
end
function M.setup_formatter(opts)
  local null_ls = require("null-ls")
  opts.sources = vim.list_extend(opts.sources or {}, {
    null_ls.builtins.formatting.sqlfluff.with({
      filetypes = { "mysql" },
      extra_args = { "--dialect", "mysql" },
    }),
    null_ls.builtins.formatting.sql_formatter.with({
      filetypes = { "mysql" },
      extra_args = { "--language", "mysql" },
    }),
  })
  return opts
end
function M.setup_filetype_detection()
  vim.filetype.add({
    extension = { mysql = "mysql" },
    pattern = { ["%.my%.sql$"] = "mysql" },
    filename = { ["mysqldump.sql"] = "mysql" },
  })
end
function M.setup_keymaps(opts)
  opts.defaults = vim.tbl_deep_extend("force",
    opts.defaults or {},
    {
      ["<leader>dm"] = { name = "+mysql" },
      ["<leader>dmf"] = { "<cmd>lua require('conform').format()<cr>", "Format MySQL" },
      ["<leader>dmt"] = { "<cmd>DBUIToggle<cr>", "Toggle DBUI" },
      ["<leader>dma"] = { "<cmd>DBUIAddConnection<cr>", "Add Connection" },
      ["<leader>dmh"] = { "<cmd>DBUIFindBuffer<cr>", "Find DB Buffer" },
      ["<leader>dme"] = {
        function()
          if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
            vim.cmd("'<,'>DB")
          else
            vim.cmd("DB")
          end
        end,
        "Execute Query" 
      },

      ["<leader>dmsd"] = { "<cmd>DB SHOW DATABASES<cr>", "Show Databases" },
      ["<leader>dmst"] = { "<cmd>DB SHOW TABLES<cr>", "Show Tables" },
      ["<leader>dmsp"] = { "<cmd>DB SHOW PROCESSLIST<cr>", "Show Processes" },
    }
  )

  return opts
end
return M
