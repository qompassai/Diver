-- /qompassai/Diver/lsp/rust_analyzer.lua
-- Qompass AI Rust_analyzer LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@source https://rust-analyzer.github.io/book/configuration.html
---@return nil
local function reload_workspace(bufnr) ---@param bufnr integer
  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    name = 'rust_analyzer',
  })
  for _, client in ipairs(clients) do
    vim.notify('Reloading Cargo Workspace')
    client:request( ---@cast client { request: fun(method: string, params: any, handler: fun(err: lsp.ResponseError|nil, result: any), token?: integer|nil) }
      'rust-analyzer/reloadWorkspace',
      nil,
      function(err) ---@param err lsp.ResponseError|nil
        if err then
          error(tostring(err))
        end
        vim.notify('Cargo workspace reloaded')
      end,
      0
    )
  end
end
---@param fname string
local function is_library(fname) ---@return string|nil
  local user_home = vim.fs.normalize(vim.env.HOME)
  local cargo_home = os.getenv('CARGO_HOME') or user_home .. '/.cargo'
  local registry = cargo_home .. '/registry/src'
  local git_registry = cargo_home .. '/git/checkouts'
  local rustup_home = os.getenv('RUSTUP_HOME') or user_home .. '/.rustup'
  local toolchains = rustup_home .. '/toolchains'
  for _, item in ipairs({ toolchains, registry, git_registry }) do
    if vim.fs.relpath(item, fname) then
      local clients = vim.lsp.get_clients({ name = 'rust_analyzer' }) ---@type vim.lsp.Client[]
      return #clients > 0 and clients[#clients].config.root_dir or nil
    end
  end
end
return ---@type vim.lsp.Config
{
  cmd = { ---@type string[]
    'rust-analyzer',
  },
  filetypes = { ---@type string[]
    'rust',
  },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local reused_dir = is_library(fname)
    if reused_dir then
      on_dir(reused_dir)
      return
    end
    local cargo_crate_dir = vim.fs.root(fname, { ---@type string|nil
      'Cargo.toml',
    })
    local cargo_workspace_root
    if cargo_crate_dir == nil then
      on_dir(vim.fs.root(fname, {
        'rust-project.json',
      }) or vim.fs.dirname(vim.fs.find('.git', {
        path = fname,
        upward = true,
      })[1]))
      return
    end
    local cmd = { ---@type string[]
      'cargo',
      'metadata',
      '--no-deps',
      '--format-version',
      '1',
      '--manifest-path',
      cargo_crate_dir .. '/Cargo.toml',
    }
    vim.system(cmd, { text = true },
      function(output) ---@param output { code: integer, stdout: string|nil, stderr: string|nil }
        if output.code == 0 then
          if output.stdout then
            local result = vim.json.decode(output.stdout) ---@type { workspace_root?: string }
            if result['workspace_root'] then
              cargo_workspace_root = vim.fs.normalize(result['workspace_root']) ---@type string|nil
            end
          end
          on_dir(cargo_workspace_root or cargo_crate_dir)
        else
          vim.schedule(function()
            vim.notify(
              ('[rust_analyzer] cmd failed with code %d: %s\n%s'):format(output.code, cmd, output.stderr)
            )
          end)
        end
      end)
  end,
  capabilities = {
    experimental = {
      serverStatusNotification = true,
      commands = {
        commands = {
          'rust-analyzer.debugSingle',
          'rust-analyzer.runSingle',
          'rust-analyzer.showReferences',
        },
      },
    },
  },
  settings = { ---@type table
    ['rust-analyzer'] = {
      assist = {
        emitMustUse = true,
        expressionFillDefault = false,
        preferSelf = false,
        termSearch = {
          borrwcheck = true,
          fuel = 1800,
        },
      },
      cachePriming = {
        enable = true,
        numThreads = 'physical',
      },
      cargo = {
        alltargets = true,
        autoreload = true,
        buildScripts = {
          enable = true,
          nvocationStrategy = 'per_workspace',
          overrideCommand = nil,
          rebuildOnSave = true,
          useRustcWrapper = true,
        },
        cfgs = {
          'debug_assertions',
          'miri',
        },
      },
      cfg = {},
      check = {
        allTargets = nil,
        command = 'clippy',
        extraArgs = {
          '--all-targets',
        },
        extraEnv = {
          '-C target-cpu=native -C debuginfo=2',
        },
      },
      checkOnSave = true,
      completion = {},
      diagnostics = {
        enable = true,
        expertimental = {
          enable = true,
        },
      },
      document = {},
      files = {},
      gotoImplementations = {},
      highlightRelated = {},
      hover = {},
      imports = {
        granularity = {
          group = 'module',
        },
      },
      inlayHints = {},
      interpret = {},
      joinLines = {},
      lens = {
        debug = {
          enable = true,
        },
        enable = true,
        implementations = {
          enable = true,
        },
        references = {
          adt = {
            enable = true,
          },
          enumVariant = {
            enable = true,
          },
          method = {
            enable = true
          },
          trait = {
            enable = true
          },
        },
        run = {
          enable = true
        },
        updateTest = {
          enable = true
        },
      },
      linkedProjects = {},
      lru = {},
      notifications = {},
      numThreads = {},
      procMacro = {},
      profiling = {},
      runnables = {},
      rustc = {},
      rustfmt = {
        extraArgs = {
          '--edition',
          '2024',
          '--style-edition',
          '2024',
          '--unstable-features',
          '--verbose',
        },
        rangeFormatting = {
          enable = true,
        },
      },
      semanticHighlighting = {
        comments = {
          enable = true,
        },
        doc = {
          comment = {
            inject = {
              enable = true,
            },
          },
        },
        operator = {
          specialization = {
            enable = true,
          },
        },
        punctuation = {
          enable = true,
          separate = {
            macro = {
              bang = false,
            },
          },
          specialization = {
            enable = true,
          },
        },
        strings = {
          enable = true,
        },
      },
      signatureInfo = {
        detail = 'full',
        enable = true,
      },
      typing = {},
      vfs = {},
      workspace = {
        symbol = {
          search = {
            discoverConfig = nil,
            excludeImports = false,
            kind = 'only_types',
            limit = 128,
          },
        },
      },
    },
  },
  ---@param init_params lsp.InitializeParams
  before_init = function(init_params, config) ---@param config vim.lsp.Config
    if config.settings and config.settings['rust-analyzer'] then
      init_params.initializationOptions = config.settings['rust-analyzer']
    end
    ---@class RaRunnableArgs
    ---@field cargoArgs string[]
    ---@field executableArgs? string[]
    ---@field cwd string
    ---@class RaRunnable
    ---@field kind string
    ---@field label string
    ---@field args RaRunnableArgs
    ---@param command table{ title: string, command: string, arguments: any[] }
    vim.lsp.commands['rust-analyzer.runSingle'] = function(command)
      local r = command.arguments[1] ---@type RaRunnable
      local cmd = { 'cargo', unpack(r.args.cargoArgs) }
      if r.args.executableArgs and #r.args.executableArgs > 0 then
        vim.list_extend(cmd, { '--', unpack(r.args.executableArgs) })
      end
      local proc = vim.system(cmd, { cwd = r.args.cwd })
      local result = proc:wait()
      if result.code == 0 then
        vim.notify(result.stdout, vim.log.levels.INFO)
      else
        vim.notify(result.stderr, vim.log.levels.ERROR)
      end
    end
  end,
  on_attach = function(_, bufnr) ---@param bufnr integer
    vim.api.nvim_buf_create_user_command(bufnr, 'LspCargoReload', function()
      reload_workspace(bufnr)
    end, { desc = 'Reload current cargo workspace' })
  end,
}