return {
  "neovim/nvim-lspconfig",
  lazy = false,
  event = { "BufReadPre", "BufNewFile" },
  cmd = { "LspInfo", "LspInstall", "LspUninstall" },
  dependencies = {
    "williamboman/mason.nvim",
    "nvimtools/none-ls.nvim",
    "williamboman/mason-lspconfig.nvim",
    "hrsh7th/cmp-nvim-lsp",
    "mfussenegger/nvim-dap",
    "mfussenegger/nvim-dap-python",
    "leoluz/nvim-dap-go",
    "mrcjkb/rustaceanvim",
  },
  config = function()
    require("mason").setup()
    require("mason-lspconfig").setup {}
    require("nvim-web-devicons").setup {
      default = true,
    }
    local dap = require "dap"

    local lspconfig = require "lspconfig"
    local capabilities = require("cmp_nvim_lsp").default_capabilities()
    local attach_lsp = false
    local lsp_defaults = {
      flags = {
        debounce_text_changes = 250,
      },
      capabilities = capabilities,
      on_attach = function(client, bufnr)
        if not attach_lsp then
          return
        end
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        if not buf_name:match "2024%-[0-9]+%.[0-9]+%-[0-9]+%.[0-9]+%.md$" then
          if client.supports_method "textDocument/formatting" then
            vim.api.nvim_create_autocmd("BufWritePre", {
              group = vim.api.nvim_create_augroup("LspFormatting", { clear = true }),
              buffer = bufnr,
              callback = function()
                vim.lsp.buf.format { async = false }
              end,
            })
          end
        end
      end,
    }

    lspconfig.util.default_config = vim.tbl_deep_extend("force", lspconfig.util.default_config, lsp_defaults)

    vim.diagnostic.config {
      virtual_text = true,
      signs = true,
      underline = true,
      update_in_insert = true,
      severity_sort = true,
    }

    local function get_lsp_cmd(package_name, executable_name)
      if vim.fn.executable(executable_name) == 1 then
        return executable_name
      end
      local mason_path = vim.fn.stdpath "data" .. "/mason/packages/" .. package_name .. "/bin/" .. executable_name
      if vim.fn.filereadable(mason_path) == 1 then
        return mason_path
      end
      return nil
    end
    -- C/C++
    lspconfig.clangd.setup {
      capabilities = capabilities,
      cmd = { get_lsp_cmd("clangd", "clangd") },
    }
      -- Docker Compose LSP Configuration
    lspconfig.docker_compose_language_service.setup {
  capabilities = capabilities,
  -- Replace custom get_lsp_cmd with direct executable
  cmd = { "docker-compose-language-service", "--stdio" },
  filetypes = {
    "Dockerfile",
    "dockerfile",
    "yaml",
    "yml",
    "Containerfile",
  },
  root_dir = lspconfig.util.root_pattern(
    "docker-compose.yml",
    "docker-compose.yaml",
    "compose.yml",
    "compose.yaml"
  ),
  settings = {
    docker = {
      linting = {
        enabled = true,
      },
    },
  },
}
    -- Deno
    lspconfig.denols.setup {
      capabilities = capabilities,
      cmd = { get_lsp_cmd("deno", "deno") },
      root_dir = lspconfig.util.root_pattern("deno.json", "deno.jsonc"),
      init_options = {
        enable = true,
        lint = true,
        unstable = true,
      },
      settings = {
        deno = {
          enable = true,
          lint = true,
          unstable = true,
        },
      },
      filetypes = {
        "typescript",
        "typescriptreact",
        "typescript.tsx",
        "javascript",
        "javascriptreact",
        "javascript.jsx",
      },
    }
    --Diagnosticls
    local enable_diagnosticls = false

    if enable_diagnosticls then
      require("lspconfig").diagnosticls.setup {
        autostart = false,
        filetypes = { "lua", "javascript", "typescript", "python" },
        init_options = {
          filetypes = {
            lua = "lua-format",
          },
          formatters = {
            ["lua-format"] = {
              command = "lua-format",
              args = {
                "--indent-width=4",
                "--column-limit=130",
              },
            },
          },
          formatFiletypes = {
            lua = "lua-format",
          },
        },
      }
    end

    -- Go --
    -- Gopls
    lspconfig.gopls.setup {
      capabilities = capabilities,
      cmd = { get_lsp_cmd("gopls", "gopls") },
      settings = {
        gopls = {
          analyses = { unusedparams = true },
          staticcheck = true,
        },
      },
    }
    --Hyprland
    lspconfig.hyprls.setup({
    on_attach = function(_, bufnr)
        local opts = { noremap = true, silent = true }
        -- Basic LSP keybindings
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", opts)
        vim.api.nvim_buf_set_keymap(bufnr, "n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", opts)
        vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>rn", "<Cmd>lua vim.lsp.buf.rename()<CR>", opts)
        vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>ca", "<Cmd>lua vim.lsp.buf.code_action()<CR>", opts)
    end,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
})
    -- Java
    lspconfig.jdtls.setup {
      capabilities = capabilities,
      cmd = { get_lsp_cmd("jdtls", "jdtls") },
    }
    -- JSON
    lspconfig.jsonls.setup {
      capabilities = capabilities,
      cmd = { get_lsp_cmd("vscode-json-languageserver", "vscode-json-languageserver") },
      commands = {
        Format = {
          function()
            vim.lsp.buf.range_formatting({}, { 0, 0 }, { vim.fn.line "$", 0 })
          end,
        },
      },
    }
    -- Lua --
    require("lspconfig").lua_ls.setup {
      cmd = { get_lsp_cmd("lua-language-server", "lua-language-server"), "-E" },
      capabilities = capabilities,
      settings = {
        Lua = {
          runtime = {
            version = (vim.fn.executable "luajit" == 1) and "LuaJIT" or "Lua 5.1",
            path = vim.split(package.path, ";"),
          },
          diagnostics = {
            globals = {
              "vim",
              "use",
              "require",
              "pcall",
              "pairs",
              "ipairs",
              "error",
              "assert",
              "print",
              "table",
              "string",
              "math",
              "os",
              "on_attach",
              "io",
              "debug",
              "package",
              "coroutine",
              "bit32",
              "utf8",
            },
            disable = { "missing-parameter", "lowercase-global", "mixed-type" },
          },
          severity = {
            ["missing-parameter"] = "Warning",
          },
          workspace = {
            library = vim.api.nvim_get_runtime_file("", true),
            maxPreload = 10000,
            preloadFileSize = 150,
            checkThirdParty = false,
          },
          telemetry = {
            enable = false,
          },
        },
      },
    }
    -- Markdown --
    -- Marksman
    lspconfig.marksman.setup {
      capabilities = capabilities,
      cmd = { get_lsp_cmd("marksman", "marksman") },
      filetypes = { "markdown", "markdown.mdx" },
      root_dir = lspconfig.util.root_pattern(".git", ".marksman.toml"),
      settings = {
        marksman = {
          lint = {
            ignore = {
              "no-consecutive-blank-lines",
            },
          },
        },
      },
    }
    -- MATLAB
    lspconfig.matlab_ls.setup { capabilities = capabilities }
    --Python --
    --(Azure-CLI, Jupyter Lab/Hub, Pyenv, Python, PyPy)
    lspconfig.pyright.setup { capabilities = capabilities }
    lspconfig.pylsp.setup { capabilities = capabilities }
    -- R
    lspconfig.r_language_server.setup { capabilities = capabilities }
    -- Ruby
    lspconfig.solargraph.setup { capabilities = capabilities }
    -- TypeScript
    lspconfig.ts_ls.setup {
      capabilities = capabilities,
      filetypes = {
        "typescript",
        "typescriptreact",
        "typescript.tsx",
        "javascript",
        "javascriptreact",
        "javascript.jsx",
      },
      root_dir = lspconfig.util.root_pattern("tsconfig.json", "jsconfig.json", ".git"),
      on_attach = function(tsclient, ts_bufnr)
        tsclient.server_capabilities.documentFormattingProvider = false
        vim.api.nvim_create_autocmd("BufWritePre", {
          buffer = ts_bufnr,
          callback = function()
            vim.cmd "Prettier"
          end,
        })
      end,
      settings = {
        javascript = {
          inlayHints = {
            parameterNames = {
              enabled = "all",
            },
            parameterTypes = {
              enabled = true,
            },
          },
        },
        typescript = {
          inlayHints = {
            parameterNames = {
              enabled = "all",
            },
            parameterTypes = {
              enabled = true,
            },
          },
        },
      },
    }
    -- TOML --
    -- Taplo
    lspconfig.taplo.setup {
      capabilities = capabilities,
      cmd = { "taplo", "lsp", "stdio" },
      filetypes = { "toml" },
      on_attach = function(toml_client, toml_bufnr)
        if toml_client.supports_method "textDocument/formatting" then
          vim.api.nvim_create_autocmd("BufWritePre", {
            group = vim.api.nvim_create_augroup("LspFormatting", { clear = true }),
            buffer = toml_bufnr,
            callback = function()
              vim.lsp.buf.format { async = true }
            end,
          })
        end
      end,
    }

    -- YAML --
    -- Yamlls
    lspconfig.yamlls.setup {
      capabilities = capabilities,
      cmd = { "yaml-language-server", "--stdio" },
      settings = {
        yaml = {
          schemas = {
            ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
            ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "docker-compose*.yml",
          },
        },
      },
      on_attach = function(yaml_client, yaml_bufnr)
        if yaml_client.supports_method "textDocument/formatting" then
          vim.api.nvim_create_autocmd("BufWritePre", {
            group = vim.api.nvim_create_augroup("YamllsFormatting", { clear = true }),
            buffer = yaml_bufnr,
            callback = function()
              vim.lsp.buf.format { async = true }
            end,
          })
        end
      end,
    }
    -- Zig --
    -- ZLS
    lspconfig.zls.setup {
      capabilities = capabilities,
      cmd = { get_lsp_cmd("zls", "zls") },
      filetypes = { "zig", "zir" },
      root_dir = lspconfig.util.root_pattern("zls.json", "build.zig", ".git"),
      single_file_support = true,
    }
  end,
}
