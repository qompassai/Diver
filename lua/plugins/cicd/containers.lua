return {
  "dgrbrady/nvim-docker",
  ft = { "dockerfile", "containerfile", "docker-compose.yaml", "docker-compose.yml" },
  lazy = true,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvimtools/none-ls.nvim",
    "mgierada/lazydocker.nvim",
    "neovim/nvim-lspconfig",
    "b0o/schemastore.nvim",
  },
  cmd = {
    "ContainerList",
    "ContainerLogs",
    "ContainerExec",
    "ContainerStart",
    "ContainerStop",
    "ContainerKill",
    "ContainerInspect",
    "ContainerRemove",
    "ContainerPrune",
    "ImageList",
    "ImagePull",
    "ImageRemove",
    "ImagePrune",
  },
  config = function()
    require("nvim-docker").setup({})

    local lspconfig = require("lspconfig")

    lspconfig.dockerls.setup({
      filetypes = { "dockerfile", "containerfile" },
      cmd = { "docker-langserver", "--stdio" },
    })

    lspconfig.yamlls.setup({
      settings = {
        yaml = {
          schemas = require('schemastore').yaml.schemas({
            extra = {
              {
                fileMatch = {
                  "docker-compose*.yml",
                  "docker-compose*.yaml"
                },
                url = "https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json",
              },
            },
          }),
          validate = true,
          completion = true,
        },
      },
    })

    local null_ls_ok, null_ls = pcall(require, "null-ls")
    if null_ls_ok then
      local builtins = null_ls.builtins

      null_ls.register({
        builtins.diagnostics.hadolint.with({
          filetypes = { "dockerfile", "containerfile" },
        }),

        builtins.diagnostics.yamllint.with({
          filetypes = { "yaml", "docker-compose.yml", "docker-compose.yaml" },
        }),

        builtins.formatting.dockerfile_formatter.with({
          filetypes = { "dockerfile", "containerfile" },
        }),
      })
    end

    vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
      pattern = { "*docker-compose*.yml", "*docker-compose*.yaml" },
      callback = function()
        vim.bo.filetype = "docker-compose.yml"
      end,
    })
  end,
}

