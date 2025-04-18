---@type LazyPluginSpec
return {
  "neovim/nvim-lspconfig",
  lazy = true,
  event = { "BufReadPre", "BufNewFile" },
  cmd = { "LspInfo", "LspInstall", "LspUninstall" },
  dependencies = {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "saghen/blink.cmp",
    "folke/lazydev.nvim",
    "mfussenegger/nvim-dap",
    "mfussenegger/nvim-dap-python",
    "leoluz/nvim-dap-go",
    "mrcjkb/rustaceanvim",
    "igorlfs/nvim-dap-view",
    {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = {
          "mfussenegger/nvim-dap",
          "nvim-neotest/nvim-nio",
          "igorlfs/nvim-dap-view",
        },
        config = function()
          require("dapui").setup()
        end,
      },
    },
  },
  config = function()
    require("config.go").setup_all()
    require("config.lua").setup_all()
    require("config.rust").setup_all()
    require("config.mason").setup()
    require("nvim-web-devicons").setup({ default = true })

    -- Setup DAP and dap-view
    local dv = require("dap-view")
    dv.setup({
      winbar = {
        show = true,
        default_section = "scopes",
        headers = {
          scopes = "scopes",
          breakpoints = "breakpoints",
          stacks = "Stacks",
          watches = "Watches",
          WinbarHeaders = "winbarheaders",
          exceptions = "exceptions",
          threads = "threads",
          repl = "repl",
          console = "console",
        },
        sections = {
          left = { "filetype", "filename" },
          right = { "line", "col" },
        },
      },
      diagnostic = {
        section_invalid = "error",
        workspace_section_not_default = "warn",
        workspace_section_has_target = "warn",
        section_dup = "warn",
        section_dup_orig = "hint",
        crate_error_fetching = "error",
        crate_dup = "warn",
        crate_dup_orig = "hint",
        crate_novers = "warn",
        crate_name_case = "warn",
        vers_upgrade = "info",
        vers_pre = "hint",
        vers_yanked = "warn",
        vers_nomatch = "warn",
        def_invalid = "error",
        feat_dup = "warn",
        feat_dup_orig = "hint",
        feat_invalid = "error",
        feat_explicit_dep = "info",
      },
      windows = {
        height = 20,
        terminal = {
          width = 80,
          shell = vim.o.shell,
          position = "right",
          hide = "auto",
          start_hidden = false,
        },
      },
      smart_insert = true,
      insert_closing_quote = true,
      autoload = true,
      autoupdate = true,
      autoupdate_throttle = 250,
      loading_indicator = true,
      search_indicator = true,
      date_format = "%Y-%m-%d",
      thousands_separator = ",",
      notification_title = "DAP View",
      curl_args = { "-sL" },
      max_parallel_requests = 4,
      expand_crate_moves_cursor = true,
      enable_update_available_warning = true,
      text = {
        title = "ï†² %s",
        pill_left = "î‚¶",
        searching = "  ï‡Ž Searching",
        nomatch = "  ï",
      },
      on_attach = function(client)
        print("Attached client:", client)
      end,
    })
  end,
}
