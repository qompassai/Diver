-- TLDR on Plugin Management

-- Add "--" ahead of import line (10=0, 25, 29, 33, 37, 42, 89) to disable
-- At minimum, keep core tools enabled.
-- Remove "--" ahead of import line (14, 25, 29, 33, 37, 42, 89) to enable
-- Go to the directory for customizing plugins
-- plugin .lua files set to lazy = true means it is conditionally loaded as needed
-- plugin .lua files set to lazy = false means it is conditionally loaded as needed
-- AI tools
-- Use cases: Develop assistance, auto-completion
if vim.fn.has("nvim-0.9.0") == 0 then
  vim.api.nvim_echo({
    { "Diver requires Neovim >= 0.9.0\n", "ErrorMsg" },
    { "Press any key to exit", "MoreMsg" },
  }, true, {})
  vim.fn.getchar()
  vim.cmd([[quit]])
  return {}
end
return {
  import = "plugins.ai",
},
-- Cloud tools
-- Use cases: Remote file management, SSH, GPG, PQC
{ import = "plugins.cloud", event = "BufReadCmd" },
-- Core tools
-- Use cases: Core dependencies and utilities (Eagerly loaded for base functionality)
{ import = "plugins.core" },
-- Data Science tools
-- Use cases: Data visualization, Jupyter, Quarto, Markdown
{ import = "plugins.data", ft = { "markdown", "jupyter", "quarto", "python", "r" } },
-- Educational tools
-- Use cases: Practice coding, learning Vim commands
{ import = "plugins.edu", cmd = { "VimBeGood", "Twilight" } },
-- Flow tools
-- Use cases: Debugging, linting, code completion, version control
{ import = "plugins.cicd" },
-- Lang tools
-- Use cases: LSP/Format/Debug/Lint/Snippets/Autocomplete
{
  import = "plugins.lang",
  ft = {
    ft = {
      "bash",
      "c",
      "c_sharp",
      "cpp",
      "css",
      "cuda",
      "containerfile",
      "dart",
      "dockerfile",
      "elixir",
      "elm",
      "f_sharp",
      "go",
      "graphql",
      "haskell",
      "html",
      "java",
      "javascript",
      "json",
      "kotlin",
      "latex",
      "lua",
      "markdown",
      "matlab",
      "mojo",
      "nim",
      "nix",
      "perl",
      "php",
      "powershell",
      "python",
      "r",
      "ruby",
      "rust",
      "scala",
      "scss",
      "sh",
      "solidity",
      "sql",
      "svelte",
      "swift",
      "teal",
      "toml",
      "typescript",
      "typst",
      "vhdl",
      "visual_basic",
      "vue",
      "yml",
      "yaml",
      "zig",
      "zsh",
    },
  },
  -- Navigation tools
  -- Use cases: File and folder navigation with "fuzzy" finding capabilities
  { import = "plugins.nav" },
  -- UI tools
  -- Use cases: User interface enhancements, status line, themes
  { import = "plugins.ui" },
}
