-- /qompassai/Diver/lsp/termux_language_server.lua
-- Qompass AI Termux Language Server LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
	cmd = { 'termux-language-server' },
	filetypes = { 'PKGBUILD' },
	root_markers = { '.git' },
}
