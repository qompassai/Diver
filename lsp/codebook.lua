-- /qompassai/Diver/lsp/codebook.lua
-- Qompass AI Codebook LSP Spec
-- Code-aware spell checker for code
------------------------------------------------------
vim.lsp.config['codebook'] = {
  cmd = { 'codebook-lsp' },
  filetypes = {
    'lua', 'vim', 'bash', 'sh', 'zsh',
    'python', 'ruby', 'javascript', 'typescript',
    'tsx', 'jsx', 'go', 'rust', 'c', 'cpp',
    'markdown', 'mdx', 'yaml', 'toml', 'json',
  },
  root_dir = vim.fn.getcwd,
  single_file_support = true,
  settings = {},
  flags = {
    debounce_text_changes = 150,
  },
}