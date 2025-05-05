-- ~/.config/nvim/lua/data/psql.lua
-----------------------------------
local common = require("config.data.common")
local M = {}
function M.setup_completion(opts)
  opts.fuzzy = opts.fuzzy or {}
  opts.fuzzy.implementation = "lua"
  if not opts.sources then
    opts.sources = {
      default = { "lsp", "path", "snippets", "buffer" },
      per_filetype = {}
    }
  end
  opts.sources.per_filetype = opts.sources.per_filetype or {}
  opts.sources.per_filetype.pgsql = {
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
      return ctx.filetype == "pgsql"
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
    { pgsql = { "pg_format", "sqlfluff"  } }
  )
  
  opts.formatters = vim.tbl_deep_extend("force",
    opts.formatters or {},
    {
      sqlfluff = {
        args = { "fix", "--dialect", "postgres", "-" },
        stdin = true,
      },
      pg_format = {
        args = { "--type-case", "lower", "--spaces", "2" },
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
      filetypes = { "pgsql" },
      root_dir = common.detect_sql_root_dir,
      settings = {
        sqlLanguageServer = {
          dialect = "postgresql"
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
      filetypes = { "pgsql" },
      extra_args = { "--dialect", "postgres" },
    }),
  })
  return opts
end
function M.setup_formatter(opts)
  local null_ls = require("null-ls")
  opts.sources = vim.list_extend(opts.sources or {}, {
    null_ls.builtins.formatting.sqlfluff.with({
      filetypes = { "pgsql" },
      extra_args = { "--dialect", "postgres" },
    }),
    null_ls.builtins.formatting.pg_format.with({
      filetypes = { "pgsql" },
    }),
  })
  return opts
end
function M.setup_filetype_detection()
  vim.filetype.add({
    extension = { 
      psql = "pgsql",
      pgsql = "pgsql"
    },
    pattern = { 
      ["%.pg%.sql$"] = "pgsql",
      ["%.postgres%.sql$"] = "pgsql"
    },
    filename = {
      ["pg_dump.sql"] = "pgsql",
    },
  })
end
function M.setup_keymaps(opts)
  opts.defaults = vim.tbl_deep_extend("force",
    opts.defaults or {},
    {
      ["<leader>dp"] = { name = "+postgres" },
      ["<leader>dpf"] = { "<cmd>lua require('conform').format()<cr>", "Format PostgreSQL" },
      ["<leader>dpt"] = { "<cmd>DBUIToggle<cr>", "Toggle DBUI" },
      ["<leader>dpa"] = { "<cmd>DBUIAddConnection<cr>", "Add Connection" },
      ["<leader>dph"] = { "<cmd>DBUIFindBuffer<cr>", "Find DB Buffer" },
      ["<leader>dpe"] = { 
        function()
          if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
            vim.cmd("'<,'>DB")
          else
            vim.cmd("DB")
          end
        end, 
        "Execute Query" 
      },
      
      ["<leader>dpd"] = { "<cmd>DB SELECT current_database()<cr>", "Current Database" },
      ["<leader>dpt"] = { "<cmd>DB SELECT * FROM pg_tables WHERE schemaname = 'public'<cr>", "List Tables" },
      ["<leader>dps"] = { "<cmd>DB SELECT * FROM pg_stat_activity<cr>", "Show Processes" },
    }
  )
  
  return opts
end
return M
