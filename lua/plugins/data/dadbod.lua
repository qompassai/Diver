return {
  {
    -- Need to install CLI to connect to databases
    -- e.g. sqlcmd for mssql
    "kristijanhusak/vim-dadbod-ui",
    lazy = true,
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
    init = function()
      vim.g.db_ui_use_nerd_fonts = 1
         -- Auto-format SQL results
      vim.g.db_ui_auto_format_results = 1
         -- Additional UI configuration
      vim.g.db_ui_win_position = "right"             -- Change UI drawer position (left/right/top/bottom)
      vim.g.db_ui_winwidth = 40                      -- Set the UI width
      vim.g.db_ui_show_help = 0                      -- Hide the help in the UI drawer
      vim.g.db_ui_auto_execute_table_helpers = 1     -- Auto-generate statements
         -- Set up autocommands for SQL files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {"sql", "mysql", "plsql"},
        callback = function()
          -- Set buffer-local options for SQL files
          vim.opt_local.expandtab = true
          vim.opt_local.shiftwidth = 2
          vim.opt_local.softtabstop = 2
          -- Enable SQL completion
          vim.opt_local.omnifunc = "vim_dadbod_completion#omni"
        end
})
    end,
    keys = {
      { "<leader>DB", "<cmd>DBUIToggle<CR>", desc = "Toggle DB UI" },
          -- Additional keybindings
      { "<leader>Df", "<cmd>DBUIFindBuffer<CR>", desc = "Find DB Buffer" },
      { "<leader>Dr", "<cmd>DBUIRenameBuffer<CR>", desc = "Rename Buffer" },
      { "<leader>Dq", "<cmd>DBUILastQueryInfo<CR>", desc = "Show Last Query" },
      { "<leader>De", function()
        -- Execute the current SQL buffer/selection and open results in a new tab
        if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
          vim.cmd("'<,'>DB")
        else
          vim.cmd("DB")
        end
      end, desc = "Execute Query" },
    },
    config = function()
      -- Set up Telescope integration if available
      local has_telescope, telescope = pcall(require, "telescope")
      if has_telescope then
        telescope.load_extension("vim_dadbod_completion")
      end
      end
      }
      }
