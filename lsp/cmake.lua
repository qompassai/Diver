-- /qompassai/Diver/lsp/cmake.lua
-- Qompass AI CMake LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------

local util = require 'lspconfig.util'
return {
	default_config = {
		cmd = { 'cmake-language-server' },
		filetypes = { 'cmake' },
		root_dir = function(fname)
			return util.root_pattern('CMakePresets.json', 'CTestConfig.cmake', '.git', 'build', 'cmake')(fname)
		end,
		single_file_support = true,
		init_options = {
			buildDirectory = 'build',
		},
	},
}
