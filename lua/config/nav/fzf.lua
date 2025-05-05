-- ~/.config/nvim/lua/config/nav/fzf.lua
-------------------------------------
local M = {}
M.options = {
  profile = "telescope",
  winopts = {
    height = 0.85,
    width = 0.85,
    preview = {
      layout = "flex",
      default = "bat",
      hidden = "hidden",
      vertical = "down:45%",
    },
    border = "rounded",
    hl = {
      border = "FloatBorder",
    },
  },
  fzf_opts = {
    ["--layout"] = "reverse-list",
    ["--info"] = "inline",
  },
  previewers = {
    builtin = { treesitter = { enable = false } },
  },
  keymap = {
    fzf = {
      ["ctrl-c"] = "abort",
      ["ctrl-q"] = "select-all+accept",
      ["ctrl-d"] = "half-page-down",
      ["ctrl-u"] = "half-page-up",
    },
  },
}

-- Store keymaps in the module
M.keymaps = {
  { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find Files" },
  { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Find Buffers" },
  { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Find in Files" },
  { "<leader>th", "<cmd>FzfLua colorschemes<cr>", desc = "Choose Colorscheme" },
  { "<leader>fs", "<cmd>FzfLua grep_cword<cr>", desc = "Find Current Word" },
  { "<leader>fh", "<cmd>FzfLua help_tags<cr>", desc = "Help Tags" },
  { "<leader>fm", "<cmd>FzfLua marks<cr>", desc = "Marks" },
  { "<leader>fc", "<cmd>FzfLua commands<cr>", desc = "Commands" },
  { "<leader>fd", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Document Symbols" },
}
function M.fzf_setup()
  local fzf = require("fzf-lua")
  fzf.setup(M.options)
  fzf.register_ui_select()
  vim.api.nvim_create_user_command("Projects", function()
    fzf.fzf_exec("find ~/projects -type d -maxdepth 2 | sort", {
      actions = {
        ["default"] = function(selected)
          vim.cmd("cd " .. selected[1])
          require("fzf-lua").files()
        end,
      },
      prompt = "Projects> ",
    })
  end, {})
end
return M
