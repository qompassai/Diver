return {
  {
    "kristijanhusak/vim-dadbod-ui",
    ft = { "sql", "mysql", "plsql" },
    lazy = true,
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
    init = function()
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_auto_format_results = 1
      vim.g.db_ui_win_position = "right"
      vim.g.db_ui_winwidth = 40
      vim.g.db_ui_show_help = 0
      vim.g.db_ui_auto_execute_table_helpers = 1
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "sql", "mysql", "plsql" },
        callback = function()
          vim.opt_local.expandtab = true
          vim.opt_local.shiftwidth = 2
          vim.opt_local.softtabstop = 2
          vim.opt_local.omnifunc = "vim_dadbod_completion#omni"
        end,
      })
    end,
    keys = {
      { "<leader>DB", "<cmd>DBUIToggle<CR>", desc = "Toggle DB UI" },
      { "<leader>Df", "<cmd>DBUIFindBuffer<CR>", desc = "Find DB Buffer" },
      { "<leader>Dr", "<cmd>DBUIRenameBuffer<CR>", desc = "Rename Buffer" },
      { "<leader>Dq", "<cmd>DBUILastQueryInfo<CR>", desc = "Show Last Query" },
      {
        "<leader>De",
        function()
          if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
            vim.cmd("'<,'>DB")
          else
            vim.cmd("DB")
          end
        end,
        desc = "Execute Query",
      },
    },
    config = function()
      local has_telescope, telescope = pcall(require, "telescope")
      if has_telescope then
        pcall(function()
          telescope.load_extension("vim_dadbod_completion")
        end)
      end
    end,
  },
}
