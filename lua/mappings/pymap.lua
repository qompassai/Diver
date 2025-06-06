-- pymap.lua
local M = {}

function M.setup_pymap()
  local map = vim.keymap.set
  local opts = { noremap = true, silent = true }

  -- Nerd Translate Legend (Alphabetical Order):

  -- 'Black': A Python code formatter that automatically formats Python code to conform to the PEP 8 style guide.
  --   Example: Like an auto-formatter that ensures consistent code style.

  -- 'Code Action': Suggestions provided by LSP to refactor, add missing imports, or fix code issues.
  --   Example: Like spellcheck for code; it suggests fixes when you have mistakes.

  -- 'Conda': A package and environment management system for Python that allows creating isolated environments.
  --   Example: Like having separate rooms for different projects, each with their own set of tools.

  -- 'DAP': Debug Adapter Protocol, a standardized way to debug programs across different editors and languages.
  --   Example: Similar to having a universal remote control that works with any TV.

  -- 'Definition': The place where a function, class, or variable is defined with its implementation.
  --   Example: The blueprint that shows exactly how something is built and works.

  -- 'Implementation': The actual code where a function or method is defined. It differs from a declaration as it contains logic.
  --   Example: If you declare a function in a header, its implementation contains the actual steps it performs.

  -- 'isort': A Python utility that sorts imports alphabetically and automatically separates them into sections.
  --   Example: Like organizing books on a shelf by category and then alphabetically.

  -- 'Jupyter': An interactive computing environment that enables users to create notebook documents with live code.
  --   Example: Like a digital lab notebook where you can write notes and run experiments.

  -- 'Lint': The process of analyzing code for potential errors, bugs, stylistic errors, and suspicious constructs.
  --   Example: Like having a proofreader check your writing for grammar and style issues.

  -- 'LSP': Language Server Protocol, a tool that provides intelligent code features like autocompletion, go-to-definition, and diagnostics.
  --   Example: Helps your editor understand code better, like suggesting how to finish typing a function name.

  -- 'Poetry': A tool for dependency management and packaging in Python that makes project management easier.
  --   Example: Like a recipe book that manages all ingredients and cooking steps for you.

  -- 'pytest': A testing framework for Python that makes it easy to write simple and scalable test cases.
  --   Example: Like a quality control system that checks if your product works as expected.

  -- 'References': Shows all occurrences of a symbol across the codebase, helping understand where and how it's used.
  --   Example: Like finding every mention of a character's name in a book to track their appearances.

  -- 'Telescope': A highly extendable fuzzy finder over lists in Neovim.
  --   Example: Like a smart search engine for your code and files.

  -- Python LSP and Development Keymaps
  map("n", "<leader>pd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Python Go to Definition" }))
  map("n", "<leader>pr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "Python Find References" }))
  map(
    "n",
    "<leader>pi",
    vim.lsp.buf.implementation,
    vim.tbl_extend("force", opts, { desc = "Python Go to Implementation" })
  )
  map("n", "<leader>pl", function()
    vim.cmd("PythonLint")
  end, vim.tbl_extend("force", opts, { desc = "Python Lint" }))

  -- Python Debugging Keymaps
  map("n", "<leader>pdm", function()
    require("dap-python").test_method()
  end, vim.tbl_extend("force", opts, { desc = "Debug Python Method" }))
  map("n", "<leader>pdc", function()
    require("dap-python").test_class()
  end, vim.tbl_extend("force", opts, { desc = "Debug Python Class" }))
  map("n", "<leader>pds", function()
    require("dap-python").debug_selection()
  end, vim.tbl_extend("force", opts, { desc = "Debug Python Selection" }))

  -- Python Testing Keymaps
  map("n", "<leader>pf", function()
    vim.cmd("PyTestFile")
  end, vim.tbl_extend("force", opts, { desc = "Test Python File" }))
  map("n", "<leader>tF", function()
    vim.cmd("PyTestFunc")
  end, vim.tbl_extend("force", opts, { desc = "Test Python Function" }))

  -- Python Project Management Keymaps
  map("n", "<leader>pi", function()
    vim.cmd("PoetryInstall")
  end, vim.tbl_extend("force", opts, { desc = "Poetry Install" }))
  map("n", "<leader>pu", function()
    vim.cmd("PoetryUpdate")
  end, vim.tbl_extend("force", opts, { desc = "Poetry Update" }))

  -- Jupyter Integration Keymaps
  map("n", "<leader>jr", function()
    vim.cmd("MoltenReevaluateCell")
  end, vim.tbl_extend("force", opts, { desc = "Reevaluate Jupyter Cell" }))
  map("n", "<leader>jn", function()
    vim.cmd("MoltenEvaluateLine")
  end, vim.tbl_extend("force", opts, { desc = "Evaluate Current Line" }))
  map("v", "<leader>je", function()
    vim.cmd("MoltenEvaluateVisual")
  end, vim.tbl_extend("force", opts, { desc = "Evaluate Visual Selection" }))

  -- Telescope Python-specific Keymaps
  map("n", "<leader>pm", function()
    vim.cmd("TelescopePythonModules")
  end, vim.tbl_extend("force", opts, { desc = "Find Python Modules" }))
  map("n", "<leader>td", "<cmd>Telescope dap<cr>", vim.tbl_extend("force", opts, { desc = "Debug with Telescope" }))
  map("n", "<leader>ts", "<cmd>Telescope symbols<cr>", vim.tbl_extend("force", opts, { desc = "Find Python Symbols" }))
  map("n", "<leader>tr", "<cmd>Telescope repo list<cr>", vim.tbl_extend("force", opts, { desc = "Find Repositories" }))
  map("n", "<leader>ti", "<cmd>Telescope import<cr>", vim.tbl_extend("force", opts, { desc = "Find Imports" }))
  map("n", "<leader>tc", "<cmd>Telescope conda<cr>", vim.tbl_extend("force", opts, { desc = "Conda Environments" }))
end
return M
