-- ~/.config/nvim/lua/config/js.lua

local M = {}

function M.setup(on_attach, capabilities)
  local lspconfig = require("lspconfig")
  local util = lspconfig.util

  local function is_deno_project(filename)
    return util.root_pattern("deno.json", "deno.jsonc", "deno.lock")(filename)
  end

  lspconfig.denols.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    root_dir = is_deno_project,
    init_options = {
      lint = true,
      unstable = true,
      suggest = {
        imports = {
          hosts = {
            ["https://deno.land"] = true,
            ["https://cdn.nest.land"] = true,
            ["https://crux.land"] = true,
          },
        },
      },
    },
    settings = {
      deno = {
        enable = true,
        lint = true,
        fmt = true,
        inlayHints = {
          parameterNames = { enabled = "all", suppressWhenArgumentMatchesName = true },
          parameterTypes = { enabled = true },
          variableTypes = { enabled = true },
          propertyDeclarationTypes = { enabled = true },
          functionLikeReturnTypes = { enabled = true },
          enumMemberValues = { enabled = true },
        },
      },
    },
  })

  lspconfig.tsserver.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    settings = {
      typescript = {
        format = {
          enable = true,
        },
      },
      javascript = {
        format = {
          enable = true,
        },
      },
    },
    root_dir = function(filename)
      if is_deno_project(filename) then
        return nil
      end
      return util.root_pattern("package.json", "tsconfig.json", "jsconfig.json", ".git")(filename)
    end,
    single_file_support = false,
  })

  lspconfig.eslint.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    settings = {
      format = true,
    },
    root_dir = lspconfig.util.root_pattern(".eslintrc", ".eslintrc.js", ".eslintrc.json", "package.json"),
  })

  local ok, null_ls = pcall(require, "null-ls")
  if ok then
    null_ls.register({
      name = "js-tools",
      sources = {
        null_ls.builtins.formatting.prettierd.with({
          filetypes = {
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
            "vue",
            "css",
            "scss",
            "less",
            "html",
            "json",
            "jsonc",
            "yaml",
            "markdown",
            "markdown.mdx",
            "graphql",
            "handlebars",
          },
        }),
        null_ls.builtins.formatting.eslint_d,
        null_ls.builtins.diagnostics.eslint_d.with({
          condition = function(utils)
            return utils.root_has_file({ ".eslintrc", ".eslintrc.js", ".eslintrc.json" })
          end,
        }),
        null_ls.builtins.code_actions.eslint_d,
      },
    })
  end
end
return M
