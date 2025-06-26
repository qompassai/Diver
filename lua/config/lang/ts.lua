-- ~/.config/nvim/lua/lang/ts.lua
------------------------------------
---@module 'config.lang.ts'
---@class TSConfig
---@field ts_conform fun(opts?: table): table
---@field ts_lsp fun(opts?: table): table
---@field ts_linter fun(opts?: table): table
---@field ts_formatter fun(opts?: table): table[]
---@field ts_filetype_detection fun(): table
---@field ts_keymaps fun(opts?: table): table
---@field ts_project_commands fun()
---@field ts_root_dir fun(fname: string): string
---@field ts_setup fun(opts?: table): TSConfig

local M = {}
function M.ts_conform(opts)
  local prettier_available = vim.fn.executable("prettier") == 1
  local prettierd_available = vim.fn.executable("prettierd") == 1
  local eslint_available = vim.fn.executable("eslint") == 1
  local eslint_d_available = vim.fn.executable("eslint_d") == 1
  local ts_formatters = {}
  if prettierd_available then
    table.insert(ts_formatters, "prettierd")
  end
  if prettier_available then
    table.insert(ts_formatters, "prettier")
  end
  if eslint_d_available then
    table.insert(ts_formatters, "eslint_d")
  end
  if eslint_available then
    table.insert(ts_formatters, "eslint")
  end
   return opts
end
function M.ts_lsp(opts)
  local function create_command_handler(command, get_arguments)
    return function()
      local arguments = get_arguments()
      if vim.lsp.commands and vim.lsp.commands.execute then
        vim.lsp.commands.execute({
          command = command,
          arguments = arguments,
        })
      else
        ---@diagnostic disable-next-line: deprecated
        vim.lsp.buf.execute_command({
          command = command,
          arguments = arguments,
        })
      end
    end
  end
  if not opts.servers then
    opts.servers = {}
  end
  opts.servers.tsserver = {
    filetypes = { "typescript", "typescriptreact" },
    settings = {
      typescript = {
        inlayHints = {
          includeInlayParameterNameHints = "all",
          includeInlayParameterNameHintsWhenArgumentMatchesName = false,
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = true,
          includeInlayPropertyDeclarationTypeHints = true,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = true,
        },
        suggest = {
          completeFunctionCalls = true,
        },
      },
      javascript = {
        inlayHints = {
          includeInlayParameterNameHints = "all",
          includeInlayParameterNameHintsWhenArgumentMatchesName = false,
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = true,
          includeInlayPropertyDeclarationTypeHints = true,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = true,
        },
        suggest = {
          completeFunctionCalls = true,
        },
      },
    },
    commands = {
      OrganizeImports = {
        create_command_handler("_typescript.organizeImports", function()
          return { vim.api.nvim_buf_get_name(0) }
        end),
        description = "Organize Imports",
      },
      AddMissingImports = {
        create_command_handler("_typescript.addMissingImports", function()
          return { vim.api.nvim_buf_get_name(0) }
        end),
        description = "Add Missing Imports",
      },
      FixAll = {
        create_command_handler("_typescript.fixAll", function()
          return { vim.api.nvim_buf_get_name(0) }
        end),
        description = "Fix All Issues",
      },
      GoToSourceDefinition = {
        create_command_handler("_typescript.goToSourceDefinition", function()
          local bufname = vim.api.nvim_buf_get_name(0)
          local row = vim.api.nvim_win_get_cursor(0)[1] - 1
          local col = vim.api.nvim_win_get_cursor(0)[2]
          return { bufname, row, col }
        end),
        description = "Go To Source Definition",
      },
    },
  }
  opts.servers.eslint = {
    filetypes = { "typescript", "typescriptreact" },
    settings = {
      codeActionOnSave = {
        enable = true,
        mode = "all",
      },
      format = true,
      quiet = false,
      onIgnoredFiles = "off",
      rulesCustomizations = {},
      run = "onType",
      validate = "on",
      packageManager = "npm",
    },
  }
  return opts
end
function M.ts_linter(opts)
  require("lint").linters_by_ft = {
    typescript = { "eslint" },
    typescriptreact = { "eslint" },
  }
  return opts
end
function M.ts_root_dir(fname)
  local util = require("lspconfig.util")
  local root = util.root_pattern(
    "tsconfig.json",
    "jsconfig.json",
    "package.json",
    ".eslintrc.js",
    ".eslintrc.json",
    ".eslintrc.cjs"
  )(fname) or util.root_pattern(".git")(fname)
  return root or vim.fn.getcwd()
end
function M.ts_formatter(opts)
  local null_ls = require("null-ls")
  opts.sources = vim.list_extend(opts.sources or {}, {
    null_ls.builtins.formatting.prettierd.with({
      filetypes = { "typescript", "typescriptreact" },
    }),
  })
  return opts
end
function M.ts_filetype_detection()
  vim.filetype.add({
    extension = {
      ts = "typescript",
      tsx = "typescriptreact",
      js = "javascript",
      jsx = "javascriptreact",
      mjs = "javascript",
      cjs = "javascript",
    },
    pattern = {
      [".*.d.ts"] = "typescript",
      ["tsconfig.*%.json"] = "jsonc",
    },
    filename = {
      ["tsconfig.json"] = "jsonc",
      [".eslintrc.js"] = "javascript",
      [".eslintrc.cjs"] = "javascript",
    },
  })
end
function M.ts_keymaps(opts)
  opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
    ["<leader>ct"] = { name = "+typescript" },
    ["<leader>ctf"] = { "<cmd>lua require('conform').format()<cr>", "Format TypeScript" },
    ["<leader>cta"] = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Code Actions" },
    ["<leader>ctr"] = { "<cmd>lua vim.lsp.buf.rename()<cr>", "Rename Symbol" },
    ["<leader>cti"] = { "<cmd>TypescriptOrganizeImports<cr>", "Organize Imports" },
    ["<leader>ctd"] = { "<cmd>TypescriptGoToSourceDefinition<cr>", "Go To Definition" },
    ["<leader>ctt"] = { "<cmd>TypescriptAddMissingImports<cr>", "Add Missing Imports" },
    ["<leader>cts"] = { "<cmd>lua require('telescope.builtin').lsp_document_symbols()<cr>", "Document Symbols" },
    ["<leader>cte"] = {
      "<cmd>lua require('conform').format({formatters = {'eslint_d'}})<cr>",
      "Format with ESLint",
    },
    ["<leader>ctp"] = {
      "<cmd>lua require('conform').format({formatters = {'prettierd'}})<cr>",
      "Format with Prettier",
    },
  })
  return opts
end
function M.ts_project_commands()
  local function execute_command(command, arguments)
    if vim.lsp.commands and vim.lsp.commands.execute then
      vim.lsp.commands.execute({
        command = command,
        arguments = arguments,
      })
    else
      ---@diagnostic disable-next-line: deprecated
      vim.lsp.buf.execute_command({
        command = command,
        arguments = arguments,
      })
    end
  end
  vim.api.nvim_create_user_command("TypescriptOrganizeImports", function()
    execute_command("_typescript.organizeImports", { vim.api.nvim_buf_get_name(0) })
  end, { desc = "Organize Imports" })
  vim.api.nvim_create_user_command("TypescriptAddMissingImports", function()
    execute_command("_typescript.addMissingImports", { vim.api.nvim_buf_get_name(0) })
  end, { desc = "Add Missing Imports" })
  vim.api.nvim_create_user_command("TypescriptFixAll", function()
    execute_command("_typescript.fixAll", { vim.api.nvim_buf_get_name(0) })
  end, { desc = "Fix All Fixable Issues" })
  vim.api.nvim_create_user_command("TypescriptGoToSourceDefinition", function()
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local col = vim.api.nvim_win_get_cursor(0)[2]
    execute_command("_typescript.goToSourceDefinition", {
      vim.api.nvim_buf_get_name(0),
      row,
      col,
    })
  end, { desc = "Go To Source Definition" })
end
return {
  conform = M.ts_conform,
  lsp = M.ts_lsp,
  linter = M.ts_linter,
  formatter = M.ts_formatter,
  keymaps = M.ts_keymaps,
  filetypes = M.ts_filetype_detection,
  commands = M.ts_project_commands,
  root_dir = M.ts_root_dir,
}
