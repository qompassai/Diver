local M = {}

function M.setup_dap()
  local dap = require("dap")
  dap.adapters.lldb = {
    type = "executable",
    command = "/usr/bin/lldb",
    name = "lldb",
  }
  dap.configurations.rust = {
    {
      name = "Launch",
      type = "lldb",
      request = "launch",
      program = function()
        return vim.fn.input("Path to executable: " .. vim.fn.getcwd() .. "/")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
    },
  }
  local dapui = require("dapui")

  --------------------------- | DAP UI | -----------------------------
  dapui.setup()
  dap.listeners.before.attach.dapui_config = function()
    dapui.open()
  end
  dap.listeners.before.launch.dapui_config = function()
    dapui.open()
  end
  dap.listeners.after.event_terminated.dapui_config = function()
    dapui.close()
  end
  dap.listeners.after.event_exited.dapui_config = function()
    dapui.close()
  end

  local jit = require("jit")
  local sysname = (jit and jit.os) or "Linux"
  local mason_path = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/"
  local codelldb_path = mason_path .. "adapter/codelldb"

  if sysname == "OSX" then
  elseif sysname == "Windows" then
    dap.adapters.lldb = {
      type = "executable",
      command = codelldb_path,
      name = "lldb",
    }
    dap.configurations.rust = {
      {
        name = "Launch",
        type = "lldb",
        request = "launch",
        program = function()
          return vim.fn.input("Path to executable: ")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = {},
      },
    }
  end
  -- LSP config --

  function M.setup_lsp(on_attach, capabilities)
    vim.g.rustaceanvim = {
      server = {
        on_attach = function(client, bufnr)
          vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
          print("Attached client:", client.name)
          if type(on_attach) == "function" then
            on_attach(client, bufnr)
          end
        end,
        capabilities = capabilities,
        settings = {
          ["rust-analyzer"] = {
            assist = {
              expressionFillDefault = "default",
              importGranularity = "module",
              importPrefix = "self",
            },
            cargo = {
              allFeatures = true,
              loadOutDirsFromCheck = true,
              runBuildScripts = true,
              features = "all",
              target = "nil",
            },
            checkOnSave = { command = "clippy" },
            diagnostics = {
              enable = true,
              experimental = { enable = true },
              disabled = { "unresolved-proc-macro", "macro-error" },
            },
            files = {
              excludeDirs = {
                ".direnv",
                ".git",
                "target",
                "node_modules",
              },
            },
            procMacro = {
              enable = true,
              attributes = {
                enable = true,
              },
            },
            inlayHints = {
              typeHints = true,
              parameterHints = true,
              chainingHints = true,
              closingBraceHints = true,
            },
          },
        },
      },
      completion = {
        callable = {
          snippets = "fill_arguments",
        },
      },
    }
  end
end
-- Crates.nvim setup
function M.setup_crates()
  local crates = require("crates")
  crates.setup({
    smart_insert = true,
    insert_closing_quote = true,
    autoload = true,
    autoupdate = true,
    autoupdate_throttle = 250,
    loading_indicator = true,
    search_indicator = true,
    date_format = "%Y-%m-%d",
    thousands_separator = ".",
    notification_title = "crates.nvim",
    curl_args = {
      "-sL",
      "--retry",
      { "1" },
      max_parallel_requests = 80,
      expand_crate_moves_cursor = true,
      enable_update_available_warning = true,
      on_attach = function(client)
        vim.bo.omnifunc = "v:lua.vim.lsp.omnifunc"
        print("Attached client:", client)
      end,
      text = {
        searching = " 🔎 Searching",
        loading = "  ⏳  Loading",
        version = "   %s",
        prerelease = "   %s",
        yanked = "   %s",
        nomatch = "   No match",
        upgrade = "   %s",
        error = "   Error fetching crate",
      },
      highlight = {
        searching = "CratesNvimSearching",
        loading = "CratesNvimLoading",
        version = "CratesNvimVersion",
        prerelease = "CratesNvimPreRelease",
        yanked = "CratesNvimYanked",
        nomatch = "CratesNvimNoMatch",
        upgrade = "CratesNvimUpgrade",
        error = "CratesNvimError",
      },
      popup = {
        autofocus = false,
        hide_on_select = false,
        copy_register = '"',
        style = "minimal",
        border = "none",
        show_version_date = true,
        show_dependency_version = true,
        max_height = 30,
        min_width = 20,
        padding = 1,
        text = {
          title = " %s",
          pill_left = "",
          pill_right = "",
          description = "%s",
          created_label = " created",
          created = "%s",
          updated_label = " updated",
          updated = "%s",
          downloads_label = " downloads      ",
          downloads = "%s",
          homepage_label = " homepage       ",
          homepage = "%s",
          repository_label = " repository     ",
          repository = "%s",
          documentation_label = " documentation  ",
          documentation = "%s",
          crates_io_label = " crates.io",
          crates_io = "%s",
          lib_rs_label = " lib.rs",
          lib_rs = "%s",
          categories_label = " categories",
          keywords_label = " keywords",
          version = "  %s",
          prerelease = " %s",
          yanked = " %s",
          version_date = "  %s",
          feature = "  %s",
          enabled = " %s",
          transitive = " %s",
          normal_dependencies_title = " Dependencies",
          build_dependencies_title = " Build dependencies",
          dev_dependencies_title = " Dev dependencies",
          dependency = "  %s",
          optional = " %s",
          dependency_version = "  %s",
          loading = "  ",
        },
        highlight = {
          title = "CratesNvimPopupTitle",
          pill_text = "CratesNvimPopupPillText",
          pill_border = "CratesNvimPopupPillBorder",
          description = "CratesNvimPopupDescription",
          created_label = "CratesNvimPopupLabel",
          created = "CratesNvimPopupValue",
          updated_label = "CratesNvimPopupLabel",
          updated = "CratesNvimPopupValue",
          downloads_label = "CratesNvimPopupLabel",
          downloads = "CratesNvimPopupValue",
          homepage_label = "CratesNvimPopupLabel",
          homepage = "CratesNvimPopupUrl",
          repository_label = "CratesNvimPopupLabel",
          repository = "CratesNvimPopupUrl",
          documentation_label = "CratesNvimPopupLabel",
          documentation = "CratesNvimPopupUrl",
          crates_io_label = "CratesNvimPopupLabel",
          crates_io = "CratesNvimPopupUrl",
          lib_rs_label = "CratesNvimPopupLabel",
          lib_rs = "CratesNvimPopupUrl",
          categories_label = "CratesNvimPopupLabel",
          keywords_label = "CratesNvimPopupLabel",
          version = "CratesNvimPopupVersion",
          prerelease = "CratesNvimPopupPreRelease",
          yanked = "CratesNvimPopupYanked",
          version_date = "CratesNvimPopupVersionDate",
          feature = "CratesNvimPopupFeature",
          enabled = "CratesNvimPopupEnabled",
          transitive = "CratesNvimPopupTransitive",
          normal_dependencies_title = "CratesNvimPopupNormalDependenciesTitle",
          build_dependencies_title = "CratesNvimPopupBuildDependenciesTitle",
          dev_dependencies_title = "CratesNvimPopupDevDependenciesTitle",
          dependency = "CratesNvimPopupDependency",
          optional = "CratesNvimPopupOptional",
          dependency_version = "CratesNvimPopupDependencyVersion",
          loading = "CratesNvimPopupLoading",
        },
        keys = {
          hide = { "q", "<esc>" },
          open_url = { "<cr>" },
          select = { "<cr>" },
          select_alt = { "s" },
          toggle_feature = { "<cr>" },
          copy_value = { "yy" },
          goto_item = { "gd", "K", "<C-LeftMouse>" },
          jump_forward = { "<c-i>" },
          jump_back = { "<c-o>", "<C-RightMouse>" },
        },
      },
      completion = {
        insert_closing_quote = true,
        text = {
          prerelease = "  pre-release ",
          yanked = "  yanked ",
        },
        cmp = {
          enabled = true,
          use_custom_kind = true,
          kind_text = {
            version = "Version",
            feature = "Feature",
          },
          kind_highlight = {
            version = "CmpItemKindVersion",
            feature = "CmpItemKindFeature",
          },
        },
        coq = {
          enabled = true,
          name = "crates.nvim",
        },
        blink = {
          use_custom_kind = true,
          kind_text = {
            version = "Version",
            feature = "Feature",
          },
          kind_highlight = {
            version = "BlinkCmpKindVersion",
            feature = "BlinkCmpKindFeature",
          },
          kind_icon = {
            version = "🅥 ",
            feature = "🅕 ",
          },
        },
        crates = {
          enabled = true,
          min_chars = 3,
          max_results = 8,
        },
      },
      null_ls = {
        enabled = true,
        name = "crates.nvim",
      },
      neoconf = {
        enabled = true,
        namespace = "crates",
      },
      lsp = {
        enabled = true,
        name = "crates.nvim",
        on_attach = function(_client)
          print("Attached client:", _client.name)
        end,
        actions = true,
        completion = true,
      },
      {
        imports = {
          granularity = {
            group = "module",
          },
          prefix = "self",
        },
        inlayHints = {
          lifetimeElisionHints = {
            enable = "always",
            useParameterNames = true,
          },
          parameterHints = true,
          typeHints = true,
        },

        lens = {
          enable = true,
          enumVariantReferences = true,
          methodReferences = true,
          references = true,
        },
        {
          rustc = {
            source = "discover",
          },
          {
            rustfmt = {
              extraArgs = { "--config", "edition=2024" },
            },
            semanticTokensProvider = {
              full = true,
              legend = {
                tokenModifiers = {},
                tokenTypes = {},
              },
              range = true,
            },
            tools = {
              inlay_hints = {
                auto = true,
                only_current_line = false,
                show_parameter_hints = true,
                parameter_hints_prefix = "<- ",
                other_hints_prefix = "=> ",
              },
              executor = "termopen",
              rustfmt = {
                overrideCommand = { "rustfmt", "+nightly", "--edition", "2024" },
              },
            },
            {
              workspace = {
                symbol = {
                  search = {
                    kind = "all_symbols",
                  },
                },
              },
            },
          },
        },
      },
    },
  })
end
-- Leptos LSP
function M.setup_leptos(on_attach, capabilities)
  local lspconfig = require("lspconfig")
  local configs = require("lspconfig.configs")
  require("lspconfig").rust_analyzer.setup({
    settings = {
      ["rust-analyzer"] = {
        checkOnSave = {
          command = "clippy",
        },
        diagnostics = {
          enable = true,
        },
        rustfmt = {
          enableRangeFormatting = true,
        },
      },
    },
    on_attach = function(client, _)
      if client.name == "rust_analyzer" then
        client.server_capabilities.documentFormattingProvider = true
      end
    end,
  })
  if not configs.leptos_ls then
    configs.leptos_ls = {
      default_config = {
        cmd = { "leptosfmt", "lsp" },
        filetypes = { "rust" },
        root_dir = lspconfig.util.root_pattern("Cargo.toml", ".git"),
      },
    }
  end
  lspconfig.leptos_ls.setup({
    on_attach = on_attach,
    capabilities = capabilities,
  })
end

function M.setup_all(on_attach, capabilities)
  M.setup_crates()
  M.setup_dap()
  M.setup_leptos(on_attach, capabilities)
  M.setup_lsp(on_attach, capabilities)
end

return M
