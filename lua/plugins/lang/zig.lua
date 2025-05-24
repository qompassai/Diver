-- /qompassai/Diver/lua/plugins/lang/zig.lua
-- ----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved

return {
  {
    "ziglang/zig.vim",
    lazy = true,
    ft = { "zig", "zon", "ziggy" },
    init = function()
      vim.g.zig_fmt_autosave = 0
      vim.g.zig_fmt_parse_errors = 0
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "zig" })
    end,
  },
  {
    "NTBBloodbath/zig-tools.nvim",
    lazy = true,
    ft = { "zig", "zon", "ziggy" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "akinsho/toggleterm.nvim",
    },
    opts = {
      autocmds = {
        format_on_save = true,
        build_on_save = true,
      },
      zls = {
        enabled = true,
        config_dir = vim.fn.stdpath("config") .. "/lua/config/zls.json",
      },
      build = {
        build_dir = "zig-out",
      },
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)
      wk.register({
        ["<leader>Z"] = {
          name = "+zig",
          b = { "<cmd>ZigBuild<CR>", "Build" },
          r = { "<cmd>ZigRun<CR>", "Run" },
          t = { "<cmd>ZigTest<CR>", "Test" },
          d = { "<cmd>ZigToggleBuildMode<CR>", "Toggle Build Mode" },
          f = { "<cmd>ZigFmt<CR>", "Format" },
        },
      })
    end,
  },
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = {
      "lawrence-laz/neotest-zig",
    },
    opts = {
      adapters = {
        ["neotest-zig"] = {},
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        zls = {
          filetypes = { "zig", "zon", "ziggy" },
          root_dir = function(fname)
            return require("lspconfig").util.root_pattern("zls.json", "build.zig", ".git")(fname)
          end,
          settings = {
            zls = {
              semantic_tokens = "partial",
              inlay_hints = {
                enable = true,
                exclude_single_argument = true,
              },
              enable_build_on_save = true,
            },
          },
        },
      },
    },
  },
  {
    "mfussenegger/nvim-dap",
    optional = true,
    config = function()
      local dap = require("dap")
      dap.adapters.zls = {
        type = "executable",
        command = "zls",
        args = { "debug" },
      }
      dap.configurations.zig = {
        {
          name = "Launch",
          type = "zls",
          request = "launch",
          program = "${file}",
          cwd = "${workspaceFolder}",
        },
      }
    end,
  },
}
