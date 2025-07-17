-- /qompassai/Diver/lsp/terraform_ls.lua
-- Qompass AI Terraform_ls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
	cmd = { 'terraform-ls', 'serve' },
	filetypes = { 'terraform', 'terraform-vars' },
	root_markers = { '.terraform', '.git' },
}
