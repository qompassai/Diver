return {
	{
		"zadirion/Unreal.nvim",
		lazy = true,
		dependencies = {
			"tpope/vim-dispatch",
		},
		config = function()
			vim.g.UnrealDir = "/home/phaedrus/Games/epic-games-store/drive_c/Program Files/Epic Games/UE_5.5.1/"
		end,
	},
}
