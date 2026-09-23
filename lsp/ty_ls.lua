-- /qompassai/Dive/lsp/ty_ls.lua
-- Qompass AI Diver Ty LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local api = vim.api

local function default_python_path()
  local candidates = vim.fn.has('win32') == 1 and {
    'python.exe',
    'python3.exe',
    'py.exe',
  } or {
    'python3',
    'python',
  }
  for _, name in ipairs(candidates) do
    local path = vim.fn.exepath(name)
    if path ~= '' then
      return path
    end
  end
  return 'python3'
end

---@param client vim.lsp.Client
---@param bufnr integer
local function on_attach(client, bufnr)
  require('config.core.lsp').on_attach(client, bufnr)
  client.server_capabilities.inlayHintProvider = nil
  client.server_capabilities.hoverProvider = false

  api.nvim_buf_create_user_command(bufnr, 'TySetPythonPath', function(command)
    if client:is_stopped() then
      vim.notify('ty is no longer attached', vim.log.levels.WARN)
      return
    end
    local candidate = vim.fn.expand(command.args)
    if vim.fn.executable(candidate) ~= 1 then
      vim.notify('Python executable not found: ' .. candidate, vim.log.levels.ERROR)
      return
    end
    local path = vim.fn.exepath(candidate)
    if path == '' then
      vim.notify('Cannot resolve Python executable', vim.log.levels.ERROR)
      return
    end
    local settings = vim.tbl_deep_extend('force', client.settings or {}, {
      ty = { python = path },
    })
    client.settings = settings
    client.config.settings = settings
    client:notify('workspace/didChangeConfiguration', {
      settings = settings,
    })
  end, {
    desc = 'Set Python interpreter for this ty workspace',
    nargs = 1,
    complete = 'file',
    force = true,
  })
end

---@type vim.lsp.Config
return {
  cmd = {
    'ty',
    'server',
  },
  filetypes = {
    'python',
  },
  init_options = {
    logFile = '/tmp/ty-lsp.log',
    logLevel = 'info',
  },
  on_attach = on_attach,
  root_markers = {
    'ty.toml',
    'pyproject.toml',
    '.git',
  },
  settings = {
    ty = {
      python = default_python_path(),
      completions = {
        autoImport = true,
      },
      configuration = {
        rules = {
          ['ambiguous-protocol-member'] = 'warn',
          ['byte-string-type-annotation'] = 'error',
          ['call-non-callable'] = 'error',
          ['call-top-callable'] = 'error',
          ['conflicting-argument-forms'] = 'error',
          ['conflicting-declarations'] = 'error',
          ['index-out-of-bounds'] = 'ignore',
          ['invalid-assignment'] = 'error',
          ['invalid-attribute-access'] = 'error',
          ['invalid-await'] = 'error',
          ['invalid-base'] = 'error',
          ['invalid-context-manager'] = 'error',
          ['invalid-declaration'] = 'error',
          ['invalid-exception-caught'] = 'error',
          ['invalid-explicit-override'] = 'error',
          ['invalid-frozen-dataclass-subclass'] = 'error',
          ['invalid-generic-class'] = 'error',
          ['invalid-ignore-comment'] = 'error',
          ['invalid-key'] = 'error',
          ['invalid-legacy-type-variable'] = 'error',
          ['invalid-metaclass'] = 'error',
          ['invalid-method-override'] = 'error',
          ['invalid-named-tuple'] = 'error',
          ['invalid-newtype'] = 'error',
          ['invalid-overload'] = 'error',
          ['invalid-parameter-default'] = 'error',
          ['invalid-paramspec'] = 'error',
          ['invalid-protocol'] = 'error',
          ['invalid-raise'] = 'error',
          ['invalid-return-type'] = 'error',
          ['invalid-super-argument'] = 'error',
          ['invalid-syntax-in-forward-annotation'] = 'error',
          ['invalid-type-alias-type'] = 'error',
          ['invalid-type-arguments'] = 'error',
          ['invalid-type-checking-constant'] = 'error',
          ['invalid-type-form'] = 'error',
          ['invalid-type-guard-call'] = 'error',
          ['invalid-type-guard-definition'] = 'error',
          ['invalid-type-variable-constraints'] = 'error',
          ['missing-argument'] = 'error',
          ['missing-typed-dict-key'] = 'error',
          ['no-matching-overload'] = 'error',
          ['non-subscriptable'] = 'error',
          ['not-iterable'] = 'error',
          ['override-of-final-method'] = 'error',
          ['parameter-already-assigned'] = 'error',
          ['positional-only-parameter-as-kwarg'] = 'error',
          ['possibly-missing-attribute'] = 'error',
          ['possibly-missing-implicit-call'] = 'error',
          ['possibly-missing-import'] = 'error',
          ['possibly-unresolved-reference'] = 'error',
          ['raw-string-type-annotation'] = 'error',
          ['redundant-cast'] = 'ignore',
          ['static-assert-error'] = 'error',
          ['subclass-of-final-class'] = 'error',
          ['super-call-in-named-tuple-method'] = 'error',
          ['too-many-positional-arguments'] = 'error',
          ['type-assertion-failure'] = 'error',
          ['unavailable-implicit-super-arguments'] = 'error',
          ['undefined-reveal'] = 'error',
          ['unknown-argument'] = 'error',
          ['unresolved-attribute'] = 'error',
          ['unresolved-global'] = 'error',
          ['unresolved-import'] = 'error',
          ['unresolved-reference'] = 'warn',
          ['unsupported-base'] = 'warn',
          ['unsupported-bool-conversion'] = 'error',
          ['unsupported-operator'] = 'error',
          ['unused-ignore-comment'] = 'ignore',
          ['useless-overload-body'] = 'warn',
          ['zero-stepsize-in-slice'] = 'error',
        },
      },
      disableLanguageServices = false,
      diagnosticMode = 'openFilesOnly',
      inlayHints = {
        callArgumentNames = true,
        variableTypes = true,
      },
      experimental = {
        autoImport = true,
        rename = true,
      },
    },
  },
}
