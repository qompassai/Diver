-- /qompassai/Diver/lua/config/ui/line.lua
-- Qompass AI Diver Statusline Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- lualine.nvim was removed 2026-09-27 at the user's request, so the
-- statusline falls back to Neovim's default 'statusline' option. This
-- module remains as the statusline seam: a future native statusline
-- implementation plugs in here via M.setup().
local M = {}

---Configure the statusline. Currently a no-op: with no statusline plugin
---installed, Neovim's default statusline applies.
function M.setup() end

return M
