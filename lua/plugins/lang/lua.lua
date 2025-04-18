return {
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      types = true,
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        "LazyVim",
      },
    },
  },
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        default = { "lazydev", "lsp", "path", "snippets", "buffer" },
        providers = {
          lazydev = {
            name = "LazyDev",
            module = "lazydev.integrations.blink",
            -- make lazydev completions top priority (see `:h blink.cmp`)
            score_offset = 100,
          },
        },
      },
    },
  },
  {
    "folke/neoconf.nvim",
    lazy = false,
    priority = 1000,
    local_settings = ".neoconf.json",
    global_settings = "neoconf.json",
    live_reload = true, -- Automatically reload LSP clients when settings change
    filetype_jsonc = true, -- Support JSONC (JSON with comments)
    plugins = {
      lspconfig = { enabled = true },
      jsonls = {
        enabled = true,
        configured_servers_only = true, -- Only show completion for configured LSP servers
      },
      lua_ls = {
        enabled_for_neovim_config = true, -- Enable annotations for Neovim config directory
        enabled = true,
      },
    },
  },
}
