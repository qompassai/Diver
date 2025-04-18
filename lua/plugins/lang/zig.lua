return {
  {
    "ziglang/zig.vim",
    lazy = true,
    ft = { "zig", "zon" },
    init = function()
      -- Disable format-on-save from zig.vim as we'll use ZLS
      vim.g.zig_fmt_autosave = 0
      -- Don't show parse errors in a separate window
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
    ft = { "zig", "zon" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "akinsho/toggleterm.nvim",
    },
    opts = {
      -- Enable autocmds for zig-tools.nvim
      autocmds = {
        -- Format on save
        format_on_save = false, -- Already handled by ZLS
        -- Run `zig build` when saving packages
        build_on_save = true,
      },
      -- ZLS configuration
      zls = {
        enabled = true,
        -- Check config location
        config_dir = vim.fn.stdpath("config") .. "/lua/config/zls.json",
      },
      build = {
        build_dir = "zig-out",
      },
    },
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
  --{
  --	"nvimtools/none-ls.nvim",
  --	optional = true,
  --	opts = function(_, opts)
  --		local null_ls = require("null-ls")
  --		opts.sources = opts.sources or {}
  --		local zigfmt = {
  --			name = "zigfmt",
  --			method = null_ls.methods.FORMATTING,
  --			filetypes = { "zig" },
  --			generator = null_ls.generator({
  --				command = "zig",
  --				args = { "fmt", "--stdin" },
  --				to_stdin = true,
  --			}),
  --		}
  -- Add the custom zigfmt source
  --		table.insert(opts.sources, zigfmt)
  --	end,
  --},
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        zls = {
          filetypes = { "zig", "zon" },
          root_dir = function(fname)
            return require("lspconfig").util.root_pattern("zls.json", "build.zig", ".git")(fname)
          end,
          settings = {
            zls = {
              semantic_tokens = "partial",
              -- Enable build-on-save diagnostics (optional)
              -- enable_build_on_save = true,
            },
          },
        },
      },
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
}
