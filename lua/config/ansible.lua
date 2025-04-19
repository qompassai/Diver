-- ~/.config/nvim/lua/config/ansible.lua
local M = {}

function M.none_ls_sources()
  local null_ls = require("null-ls")
  local formatting = null_ls.builtins.formatting
  local diagnostics = null_ls.builtins.diagnostics
  local code_actions = null_ls.builtins.code_actions

  local ansible_sources = {
    diagnostics.ansiblelint.with({
      method = null_ls.methods.DIAGNOSTICS,
      ft = { "yaml.ansible", "ansible" },
      extra_args = { "--parseable-severity" },
    }),
    formatting.prettier.with({
      method = null_ls.methods.FORMATTING,
      ft = { "yaml", "yaml.ansible", "ansible" },
      extra_args = { "--parser", "yaml" },
    }),
    diagnostics.yamllint.with({
      method = null_ls.methods.DIAGNOSTICS,
      ft = { "yaml", "yaml.ansible" },
    }),
    code_actions.statix.with({
      method = null_ls.methods.CODE_ACTION,
      ft = { "yaml.ansible", "ansible" },
    }),
  }
  return ansible_sources
end

function M.setup(on_attach, capabilities)
  local lspconfig = require("lspconfig")

  lspconfig.ansiblels.setup({
    cmd = { "ansible-language-server", "--stdio" },
    filetypes = { "yaml.ansible", "ansible" },
    settings = {
      ansible = {
        ansible = {
          path = "ansible",
        },
        executionEnvironment = {
          enabled = false,
        },
        python = {
          interpreterPath = "python",
        },
        validation = {
          enabled = true,
          lint = {
            enabled = true,
            path = "ansible-lint",
          },
        },
      },
    },
    on_attach = function(client, bufnr)
      vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
      if type(on_attach) == "function" then
        on_attach(client, bufnr)
      end
    end,
    capabilities = capabilities,
  })

  lspconfig.yamlls.setup({
    filetypes = { "yaml", "yaml.ansible" },
    settings = {
      yaml = {
        schemas = require("schemastore").yaml.schemas(),
        validate = true,
        format = {
          enable = true,
        },
        hover = true,
        completion = true,
      },
    },
    on_attach = on_attach,
    capabilities = capabilities,
  })

  vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    pattern = { "*/playbooks/*.yml", "*/roles/*.yml", "*/inventory/*.yml", "*/host_vars/*.yml", "*/group_vars/*.yml" },
    callback = function()
      vim.bo.filetype = "yaml.ansible"
    end,
  })
end

function M.setup_conform()
  local conform_ok, conform = pcall(require, "conform")
  if conform_ok then
    conform.setup({
      formatters_by_ft = {
        ["yaml.ansible"] = { "yamlfmt", "prettier" },
        ansible = { "yamlfmt", "prettier" },
      },
    })
  end
end

function M.setup_all(opts)
  M.setup(opts.on_attach, opts.capabilities)

  local null_ls_ok, null_ls = pcall(require, "null-ls")
  if null_ls_ok then
    local sources = M.none_ls_sources()
    for _, source in ipairs(sources) do
      null_ls.register(source)
    end
  else
    vim.notify("null-ls not available, Ansible sources not registered", vim.log.levels.WARN)
  end

  M.setup_conform()

  local ts_ok, ts_configs = pcall(require, "nvim-treesitter.configs")
  if ts_ok then
    ts_configs.setup({
      ensure_installed = { "yaml" },
    })
  end
end

return M

