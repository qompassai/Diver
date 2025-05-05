---~/.config/nvim/nvim/lua/plugins/cicd/tree.lua
------------------------------------------------
return {
  "nvim-neo-tree/neo-tree.nvim",
  lazy = true,
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
    "3rd/image.nvim",
  },
  event = "VimEnter",
  opts = function()
    return require("config.nav.tree").setup({
      -- You can override any defaults here if needed
      --      close_if_last_window = true,
      --      enable_git_status = true,
      -- Other options as needed
    })
  end,
}
