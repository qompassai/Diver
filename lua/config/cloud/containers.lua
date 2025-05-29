-- ~/.config/nvim/lua/config/container.lua
local M = {}
local null_ls = require("null-ls")
local b = null_ls.builtins

local function mark_pure(src) return src.with({ command = "true" }) end

function M.docker_opts()
  return {
    ui = {
      select = {
        enabled = true,
        backend = "fzf", -- can be "telescope", "fzf", or "nui"
        float_opts = {
          relative = "editor",
          width = 0.8,
          height = 0.8,
          border = "rounded",
        },
      },
    },
    docker = {
      cmd = "docker",
      compose_cmd = "docker-compose",
    },
  }
end

function M.none_ls_sources()
  return {
    b.diagnostics.hadolint.with({
      filetypes = { "dockerfile", "containerfile" },
    }),

    b.diagnostics.yamllint.with({
      filetypes = { "yaml", "docker-compose.yml", "docker-compose.yaml" },
    }),

    b.formatting.dockerfile_formatter.with({
      filetypes = { "dockerfile", "containerfile" },
    }),

    mark_pure(b.diagnostics.todo_comments),
    mark_pure(b.diagnostics.trail_space),
  }
end

function M.schema_opts()
  return {
    extra = {
      {
        fileMatch = {
          "docker-compose*.yml",
          "docker-compose*.yaml",
          "compose.yml",
          "compose.yaml",
        },
        url = "https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json",
      },
      {
        fileMatch = { "Dockerfile*", "containerfile*" },
        url = "https://raw.githubusercontent.com/moby/buildkit/master/frontend/dockerfile/schema/dockerfile.json",
      },
    },
  }
end

function M.setup_lsp(on_attach, capabilities)
  local lspconfig = require("lspconfig")

  lspconfig.dockerls.setup({
    filetypes = { "dockerfile", "containerfile" },
    cmd = { "docker-langserver", "--stdio" },
    on_attach = on_attach,
    capabilities = capabilities,
  })

  lspconfig.yamlls.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    settings = {
      yaml = {
        schemas = require('schemastore').yaml.schemas(M.schema_opts()),
        validate = true,
        completion = true,
        hover = true,
        format = {
          enable = true,
          singleQuote = false,
          bracketSpacing = true,
        },
      },
    },
  })
end

function M.setup_filetype_detection()
  vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    pattern = { "*docker-compose*.yml", "*docker-compose*.yaml", "compose.yml", "compose.yaml" },
    callback = function()
      vim.bo.filetype = "docker-compose.yml"
    end,
  })

  vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    pattern = { "*Dockerfile*", "*containerfile*", "*Containerfile*" },
    callback = function()
      vim.bo.filetype = "dockerfile"
    end,
  })
end

function M.setup_all(opts)
  opts = opts or {}

  require("nvim-docker").setup(M.docker_opts())

  M.setup_lsp(opts.on_attach, opts.capabilities)

  local sources = M.none_ls_sources()
  for _, source in ipairs(sources) do
    null_ls.register(source)
  end

  M.setup_filetype_detection()

  return M.docker_opts()
end

return M

