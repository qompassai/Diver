-- ~/.config/nvim/lua/config/cicd/ansible.lua
local M = {}

function M.none_ls_sources()
  local null_ls = require("null-ls")
  local format = null_ls.builtins.formatting
  local diag = null_ls.builtins.diagnostics
  local c_a = null_ls.builtins.code_actions
  return {
    diag.ansiblelint.with({
      method = null_ls.methods.DIAGNOSTICS,
      ft = { "yaml.ansible", "ansible" },
      extra_args = { "--parseable-severity" },
    }),
    format.prettierd.with({
      method = null_ls.methods.FORMATTING,
      ft = { "yaml", "yaml.ansible", "ansible" },
      extra_args = { "--parser", "yaml" },
    }),
    diag.yamllint.with({
      method = null_ls.methods.DIAGNOSTICS,
      ft = { "yaml", "yaml.ansible" },
      cmd = "yamllint"
    }),
    c_a.statix.with({
      method = null_ls.methods.CODE_ACTION,
      ft = { "yaml.ansible", "ansible" },
    }),
  }
end
function M.setup_lsp(on_attach, capabilities)
  local lspconfig = require("lspconfig")
  lspconfig.ansiblels.setup({
    cmd = { "ansible-language-server", "--stdio" },
    filetypes = { "yaml.ansible", "ansible" },
    settings = {
      ansible = {
        ansible = { path = "ansible" },
        executionEnvironment = { enabled = true },
        python = { interpreterPath = "python" },
        validation = {
          enabled = true,
          lint = { enabled = true, path = "ansible-lint" },
        },
      },
    },
    on_attach = function(client, bufnr)
      vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
      if on_attach then
        on_attach(client, bufnr)
      end
    end,
    capabilities = capabilities or vim.lsp.protocol.make_client_capabilities(),
  })
end

function M.setup_ts()
  local ts_ok, ts_configs = pcall(require, "nvim-treesitter.configs")
  if ts_ok then
    ts_configs.setup({
      ensure_installed = { "yaml" },
      sync_install = false,
      auto_install = true,
      highlight = { enable = true, additional_vim_regex_highlighting = true },
      indent = { enable = true },
    })
  end
end

function M.setup_conform()
  local conform_ok, conform = pcall(require, "conform")
  if conform_ok then
    conform.setup({
      formatters_by_ft = {
        ["yaml"] = { "prettierd" },
        ["yaml.ansible"] = { "ansible_lint" },
        ["ansible"] = { "ansible_lint" },
      },
      formatters = {
        ansible_lint = {
          command = "ansible-lint",
          args = { "-f", "codeclimate", "-q", "--fix=all", "$FILENAME" },
          stdin = false,
          exit_codes = { 0, 2 },
        },
        prettierd = {
          args = { "--parser", "yaml" },
        },
      },
    })
  end
end

function M.setup_ansible(opts)
  vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    pattern = { "*/playbooks/*.yml", "*/roles/*.yml", "*/inventory/*.yml", "*/host_vars/*.yml", "*/group_vars/*.yml" },
    callback = function()
      vim.bo.filetype = "yaml.ansible"
    end,
  })

  M.setup_lsp(opts and opts.on_attach, opts and opts.capabilities)

  local null_ls_ok, null_ls = pcall(require, "null-ls")
  if null_ls_ok then
    null_ls.setup({ sources = M.none_ls_sources() })
  else
    vim.notify("null-ls not available, Ansible sources not registered", vim.log.levels.WARN)
  end

  M.setup_conform()

  M.setup_ts()
end

return M

