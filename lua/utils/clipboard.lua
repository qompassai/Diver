-- /qompassai/Diver/lua/utils/clipboard.lua
-- Qompass AI Clipboard Integration for Wayland
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------

local M = {}

function M.setup()
	if vim.fn.has("unix") == 1 then
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
			vim.notify("[clipboard] using wl-clipboard ✂️", vim.log.levels.INFO)
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
			vim.notify("[clipboard] using xclip 📋", vim.log.levels.INFO)
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
			vim.notify("[clipboard] using xsel 🚀", vim.log.levels.INFO)
		else
			vim.notify("[clipboard] No supported clipboard tool found", vim.log.levels.WARN)
		end
	end
end

return M
