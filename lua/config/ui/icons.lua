-- /qompassai/Diver/lua/config/ui/icons.lua
-- Qompass AI Diver Icons Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}
M.devicons = {
	override = {
		bash = {
			icon = " ",
			color = "#4EAA25",
			cterm_color = "35",
			name = "Bash",
		},
		css = {
			icon = " ",
			color = "#563d7c",
			cterm_color = "60",
			name = "CSS",
		},
		docker = {
			icon = " ",
			color = "#2496ed",
			cterm_color = "33",
			name = "Docker",
		},
		go = { icon = " ", color = "#00ADD8", cterm_color = "38", name = "Go" },
		haskell = {
			icon = " ",
			color = "#5e5086",
			cterm_color = "98",
			name = "Haskell",
		},
		html = {
			icon = " ",
			color = "#e44d26",
			cterm_color = "202",
			name = "HTML",
		},
		javascript = {
			icon = " ",
			color = "#f7df1e",
			cterm_color = "220",
			name = "JavaScript",
		},
		json = {
			icon = "ﬥ",
			color = "#cbcb41",
			cterm_color = "185",
			name = "Json",
		},
		jsonc = {
			icon = "ﬥ",
			color = "#cbcb41",
			cterm_color = "185",
			name = "JSONConfig",
		},
		jupyter = {
			icon = " ",
			color = "#f28e1c",
			cterm_color = "214",
			name = "Jupyter",
		},
		lua = {
			icon = " ",
			color = "#56b6c2",
			cterm_color = "74",
			name = "Lua",
		},
		markdown = {
			icon = " ",
			color = "#519aba",
			cterm_color = "67",
			name = "Markdown",
		},
		python = {
			icon = " ",
			color = "#3572A5",
			cterm_color = "67",
			name = "Python",
		},
		rust = {
			icon = " ",
			color = "#dea584",
			cterm_color = "173",
			name = "Rust",
		},
		sqls = {
			icon = " ",
			color = "#dad8d8",
			cterm_color = "250",
			name = "SQL",
		},
		stylua = {
			icon = " ",
			color = "#56b6c2",
			cterm_color = "74",
			name = "Stylua",
		},
		svelte = {
			icon = " ",
			color = "#ff3e00",
			cterm_color = "202",
			name = "Svelte",
		},
		tailwindcss = {
			icon = "󰞁 ",
			color = "#38bdf8",
			cterm_color = "39",
			name = "TailwindCSS",
		},
		terraform = {
			icon = " ",
			color = "#5c4ee5",
			cterm_color = "99",
			name = "Terraform",
		},
		tex = {
			icon = " ",
			color = "#3d6117",
			cterm_color = "64",
			name = "TeX",
		},
		thrift = {
			icon = " ",
			color = "#D12127",
			cterm_color = "167",
			name = "Thrift",
		},
		tfsec = {
			icon = " ",
			color = "#f30067",
			cterm_color = "197",
			name = "TFSec",
		},
		typescript = {
			icon = " ",
			color = "#3178c6",
			cterm_color = "68",
			name = "TypeScript",
		},
		vim = {
			icon = " ",
			color = "#019833",
			cterm_color = "28",
			name = "VimLanguageServer",
		},
		vimls = {
			icon = " ",
			color = "#019833",
			cterm_color = "28",
			name = "VimLanguageServer",
		},
		yaml = {
			icon = " ",
			color = "#6e9fda",
			cterm_color = "39",
			name = "Yaml",
		},
		zsh = {
			icon = " ",
			color = "#428850",
			cterm_color = "65",
			name = "Zsh",
		},
	},
	default = true,
	color_icons = true,
}

M.nonicons = {
	default = false,
	icons = {
		ai = "󰞉 ",
		cloud = " ",
		data = " ",
		docker = " ",
		dotnet = " ",
		edu = " ",
		file = " ",
		folder = " ",
		git_branch = " ",
		go = " ",
		js = " ",
		json = "ﬥ",
		haskell = " ",
		java = " ",
		lua = " ",
		markdown = " ",
		nimble = " ",
		perl = " ",
		php = " ",
		python = " ",
		ruby = " ",
		rust = " ",
		scala = " ",
		sh = " ",
		swift = " ",
		toml = " ",
		yaml = " ",
		zig = "  ",
	},
}
function M.icons_devicons(opts)
	opts = opts or {}
	require("nvim-web-devicons").setup(M.devicons)
	vim.cmd([[
    augroup DevIconsRefresh
      autocmd!
      autocmd BufEnter * lua require("nvim-web-devicons").refresh()
    augroup END
  ]])
end

function M.icons_nonicons(opts)
	opts = opts or {}
	require("nvim-nonicons").setup(M.nonicons)
end

M.icons_highlights = function()
	local highlights = {
		MathBlock = { bg = "#1e1e2e", fg = "#89b4fa" },
		CodeBlock = { bg = "#1e1e2e", fg = "#a6e3a1" },
		MarkdownBold = { bold = true, fg = "#f5c2e7" },
		MarkdownItalic = { italic = false, fg = "#89dceb" },
		MarkdownHeading = { bold = true, fg = "#f38ba8" },
	}
	for name, attrs in pairs(highlights) do
		vim.api.nvim_set_hl(0, name, attrs)
	end
end
function M.icons_cfg(opts)
	opts = opts or {}
	M.icons_devicons(opts)
	M.icons_nonicons(opts)
	M.icons_highlights()
end

return M
