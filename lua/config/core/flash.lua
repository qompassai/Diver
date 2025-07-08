-- Qompass AI Diver – Flash.nvim core configuration ---------------------------
-- Everything that can possibly live outside the spec file stays in here
-------------------------------------------------------------------------------
local M = {}

---@param extra table|nil allow the spec to patch/override at call-site
function M.flash_opts(extra)
  local o = {
    modes = {
      search = {
        enabled   = true,
        highlight = { backdrop = true },
        jump      = { history = true, register = true, nohlsearch = true },
      },
      char = {
        enabled = true,
        -- autohide during operator-pending yank: e.g.  **y**f(
        config = function(opts)
          opts.autohide =
            vim.fn.mode(true):find("no") and vim.v.operator == "y"
        end,
        chars = { "f", "F", "t", "T", ";", "," },
        keys  = { "f", "F", "t", "T", ";", "," },
      },
      treesitter = {
        labels = "abcdefghijklmnopqrstuvwxyz",
        jump   = { pos = "start" },
        search = { incremental = true },
      },
    },
    prompt = {
      enabled = true,
      prefix  = { { "⚡", "FlashPromptIcon" } },
    },
  }
  if extra then
    o = vim.tbl_deep_extend("force", o, extra)
  end
  return o
end

function M.flash_cfg(extra)
  require("flash").setup(M.flash_opts(extra))
end

return M
