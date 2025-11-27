-- /qompassai/Diver/lua/utils/clipboard.lua
-- Qompass AI Clipboard Integration for Wayland/X11
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}

--- @param debug boolean? Optional. Print debug info if true
function M.setup(debug)
  local function log(msg, level)
    if debug then
      vim.schedule(function()
        vim.notify("[clipboard] " .. msg, level or vim.log.levels.INFO)
      end)
    end
  end

  if vim.fn.has("unix") ~= 1 then
    log("Unsupported platform (not unix)", vim.log.levels.WARN)
    return
  end

  if vim.fn.executable("wl-copy") == 1 and vim.fn.executable("wl-paste") == 1 then
    vim.g.clipboard = {
      name = "wl-clipboard",
      copy = {
        ["+"] = "wl-copy --foreground --type text/plain",
        ["*"] = "wl-copy --primary --foreground --type text/plain",
      },
      paste = {
        ["+"] = "wl-paste --no-newline",
        ["*"] = "wl-paste --primary --no-newline",
      },
      cache_enabled = 1,
    }
    log("using wl-clipboard ✅")
  elseif vim.fn.executable("xclip") == 1 then
    vim.g.clipboard = {
      name = "xclip",
      copy = {
        ["+"] = "xclip -selection clipboard",
        ["*"] = "xclip -selection primary",
      },
      paste = {
        ["+"] = "xclip -selection clipboard -o",
        ["*"] = "xclip -selection primary -o",
      },
      cache_enabled = 1,
    }
    log("using xclip ✅")
  elseif vim.fn.executable("xsel") == 1 then
    vim.g.clipboard = {
      name = "xsel",
      copy = {
        ["+"] = "xsel --clipboard --input",
        ["*"] = "xsel --primary --input",
      },
      paste = {
        ["+"] = "xsel --clipboard --output",
        ["*"] = "xsel --primary --output",
      },
      cache_enabled = 1,
    }
    log("using xsel ✅")
  else
    log("No supported clipboard tool found ❌", vim.log.levels.WARN)
  end
end

return M
