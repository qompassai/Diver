local M = {}
function M.setup()
  ---@class MasonNullLsMethods
  ---@field diagnostics boolean
  ---@field formatting boolean
  ---@field code_actions boolean
  ---@field completion boolean
  ---@field hover boolean

  ---@class MasonNullLsSettings
  ---@field handlers table | nil
  ---@field methods MasonNullLsMethods | nil
  ---@field ensure_installed table
  ---@field automatic_installation boolean | table

  local has_null_ls = pcall(require, "null-ls")
  local has_mason = pcall(require, "mason")
  if not has_null_ls then
    vim.notify("null-ls is not installed, mappings may fail", vim.log.levels.ERROR)
    return false
  end
  if not has_mason then
    vim.notify("mason is not installed, automatic installation may fail", vim.log.levels.ERROR)
  end
  local DEFAULT_SETTINGS = {
    -- Lua
    "stylua", -- Already included
    "luacheck", -- Lua linter
    -- Rust
    "rustfmt", -- Rust formatter
    "clippy", -- Rust linter with advanced diagnostics
    -- Golang
    "gofumpt", -- Stricter gofmt
    "goimports", -- Organizes and formats Go imports
    "golangci-lint", -- Meta-linter for Go
    "gomodifytags", -- Modify struct tags
    -- Python
    "black", -- Python formatter
    "isort", -- Python import sorter
    "pylint", -- Python linter
    "mypy", -- Python type checker
    "flake8", -- Python style guide enforcer
    "ruff", -- Fast Python linter (alternative)
    "autopep8", -- Formatter that follows PEP 8
  }
  -- A list of null-ls methods to ignore when calling handlers.
  -- This setting is useful if some functionality is handled by other plugins such as `conform` and `nvim-lint`
  methods = {
    diagnostics = true,
    formatting = true,
    code_actions = true,
    completion = true,
    hover = true,
    -- NOTE: this is left here for future porting in case needed
    -- Whether sources that are set up (via null-ls) should be automatically installed if they're not already installed.
    -- This setting has no relation with the `ensure_installed` setting.
    -- Can either be:
    --   - false: Servers are not automatically installed.
    --   - true: All servers set up via lspconfig are automatically installed.
    --   - { exclude: string[] }: All servers set up via mason-null-ls, except the ones provided in the list, are automatically installed.
    --       Example: automatic_installation = { exclude = { "stylua", "eslint", } }
    automatic_installation = true,
    handlers = {
      function(source_name)
        local null_ls = require("null-ls")
        if source_name == "stylua" then
          null_ls.register(null_ls.builtins.formatting.stylua)
        elseif source_name == "black" then
          null_ls.register(null_ls.builtins.formatting.black.with({
            extra_args = { "--line-length", "88" },
          }))
        elseif source_name == "isort" then
          null_ls.register(null_ls.builtins.formatting.isort.with({
            extra_args = { "--profile", "black" },
          }))
        elseif source_name == "rustfmt" then
          null_ls.register(null_ls.builtins.formatting.rustfmt.with({
            extra_args = { "--edition", "2021" },
          }))
        elseif source_name == "gofumpt" then
          null_ls.register(null_ls.builtins.formatting.gofumpt)
        elseif source_name == "goimports" then
          null_ls.register(null_ls.builtins.formatting.goimports)
        elseif source_name == "autopep8" then
          null_ls.register(null_ls.builtins.formatting.autopep8)
        -- Linter registration
        elseif source_name == "luacheck" then
          null_ls.register(null_ls.builtins.diagnostics.luacheck.with({
            extra_args = { "--no-color", "--no-global" },
          }))
        elseif source_name == "pylint" then
          null_ls.register(null_ls.builtins.diagnostics.pylint.with({
            diagnostics_postprocess = function(diagnostic)
              diagnostic.severity = diagnostic.message:find("error") and 1
                or diagnostic.message:find("warning") and 2
                or diagnostic.message:find("convention") and 3
                or diagnostic.message:find("refactor") and 4
                or 3
            end,
          }))
        elseif source_name == "mypy" then
          null_ls.register(null_ls.builtins.diagnostics.mypy.with({
            extra_args = { "--ignore-missing-imports", "--disallow-untyped-defs" },
          }))
        elseif source_name == "flake8" then
          null_ls.register(null_ls.builtins.diagnostics.flake8)
        elseif source_name == "ruff" then
          null_ls.register(null_ls.builtins.diagnostics.ruff)
        elseif source_name == "clippy" then
          null_ls.register(null_ls.builtins.diagnostics.clippy.with({
            extra_args = { "--", "-W", "clippy::all" },
          }))
        elseif source_name == "golangci-lint" then
          null_ls.register(null_ls.builtins.diagnostics.golangci_lint)
        -- Code actions
        elseif source_name == "gomodifytags" then
          null_ls.register(null_ls.builtins.code_actions.gomodifytags)
        end
      end,
      -- Lua
      stylua = function()
        require("null-ls").register(require("null-ls").builtins.formatting.stylua.with({
          condition = function(utils)
            return utils.root_has_file({ ".stylua.toml", "stylua.toml" })
          end,
        }))
      end,
      -- Python
      black = function()
        local null_ls = require("null-ls")
        null_ls.register(null_ls.builtins.formatting.black.with({
          command = vim.fn.stdpath("data") .. "/mason/bin/black",
          extra_args = { "--line-length", "88" },
        }))
      end,
    },
  }

  M._DEFAULT_SETTINGS = DEFAULT_SETTINGS
  M.current = M._DEFAULT_SETTINGS

  ---@param opts MasonNullLsSettings
  function M.set(opts)
    M.current = vim.tbl_deep_extend("force", M.current, opts)
    vim.validate({
      ensure_installed = {
        name = "ensure_installed",
        arg = M.current.ensure_installed,
        type = "table",
        optional = true,
      },
      methods = { name = "methods", arg = M.current.methods, type = "table", optional = true },
      automatic_installation = {
        name = "automatic_installation",
        arg = M.current.automatic_installation,
        type = { "boolean", "table" },
        optional = true,
      },
      handlers = { name = "handlers", arg = M.current.handlers, type = "table", optional = true },
    })
  end
end
return M
