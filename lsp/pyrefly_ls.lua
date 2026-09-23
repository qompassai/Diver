-- /qompassai/Diver/lsp/pyrefly_ls.lua
-- Qompass AI Pyrefly LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------
local api = vim.api

local function default_python_path()
  local candidates = vim.fn.has('win32') == 1 and { 'python.exe', 'python3.exe', 'py.exe' } or { 'python3', 'python' }
  for _, name in ipairs(candidates) do
    local path = vim.fn.exepath(name)
    if path ~= '' then
      return path
    end
  end
  return 'python3'
end

---@param bufnr integer
local function safe_inlay_hints(bufnr)
  local hints = vim.lsp.inlay_hint
  if not hints then
    return
  end
  hints.enable(false, { bufnr = bufnr })
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      hints.enable(true, { bufnr = bufnr })
    end
  end, 150)
end

-- `pyrefly infer FILE` runs in "single-file mode", which ignores
-- project-excludes from pyrefly.toml/pyproject.toml entirely. Passing
-- --project-excludes on the CLI does not replace Pyrefly's built-in
-- defaults either -- those defaults (including `**/.[!/.]*/**`, which
-- excludes any path containing a hidden directory component) are always
-- appended on top, per Pyrefly's own docs. Only
-- --disable-project-excludes-heuristics actually zeroes out that
-- built-in default list, after which our own --project-excludes values
-- become the entire effective exclude set.
local PROJECT_EXCLUDES = {
  '**/node_modules/**',
  '**/__pycache__/**',
  '**/venv/**',
}

---@param path string
---@param on_done fun(ok: boolean, err: string?)
local function run_infer_on_file(path, on_done)
  assert(type(path) == 'string' and path ~= '', 'run_infer_on_file requires a non-empty path')
  local cmd = { 'pyrefly', 'infer', path, '--disable-project-excludes-heuristics' }
  for _, pattern in ipairs(PROJECT_EXCLUDES) do
    cmd[#cmd + 1] = '--project-excludes'
    cmd[#cmd + 1] = pattern
  end
  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        on_done(false, (result.stderr ~= '' and result.stderr) or ('pyrefly infer exited ' .. result.code))
        return
      end
      on_done(true, nil)
    end)
  end)
end

---@param client vim.lsp.Client
---@param bufnr integer
local function on_attach(client, bufnr)
  require('config.core.lsp').on_attach(client, bufnr)
  client.server_capabilities.semanticTokensProvider = nil

  local augroup = api.nvim_create_augroup('pyrefly_hint_refresh_' .. bufnr, { clear = true })
  api.nvim_create_autocmd('BufWritePre', {
    group = augroup,
    buffer = bufnr,
    callback = function()
      vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
    end,
  })
  api.nvim_create_autocmd('BufWritePost', {
    group = augroup,
    buffer = bufnr,
    callback = function()
      safe_inlay_hints(bufnr)
    end,
  })

  api.nvim_buf_create_user_command(bufnr, 'PyreflySetPythonPath', function(command)
    if client:is_stopped() then
      vim.notify('Pyrefly is no longer attached', vim.log.levels.WARN)
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
    local settings = vim.tbl_deep_extend('force', client.config.settings or {}, {
      python = { pythonPath = path },
      pyrefly = { python_interpreter = path },
    })
    client.config.settings = settings
    client:notify('workspace/didChangeConfiguration', { settings = settings })
  end, {
    desc = 'Set Python interpreter for this Pyrefly workspace',
    nargs = 1,
    complete = 'file',
    force = true,
  })

  -- Mutates the current file on disk directly, matching `pyrefly infer`'s
  -- own CLI behavior. Reloads the buffer afterward so you see the result
  -- immediately. No undo safety net beyond Neovim's own undo history --
  -- prefer `:PyreflyInferPreview` first on anything you have not reviewed.
  api.nvim_buf_create_user_command(bufnr, 'PyreflyInfer', function()
    local path = vim.api.nvim_buf_get_name(bufnr)
    if path == '' then
      vim.notify('Buffer has no file on disk to infer against', vim.log.levels.ERROR)
      return
    end
    vim.cmd.write()
    vim.notify('Running pyrefly infer...', vim.log.levels.INFO)
    run_infer_on_file(path, function(ok, err)
      if not ok then
        vim.notify('pyrefly infer failed: ' .. tostring(err), vim.log.levels.ERROR)
        return
      end
      if vim.api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_call(bufnr, function()
          vim.cmd('checktime')
          vim.cmd('edit!')
        end)
      end
      vim.notify('pyrefly infer applied. Review the diff before committing.', vim.log.levels.WARN)
    end)
  end, {
    desc = 'Run pyrefly infer on this file in place, then reload the buffer',
    force = true,
  })

  -- Safe preview: runs inference against a throwaway temp copy, never
  -- touches the real file, and opens a unified diff for review. Nothing
  -- is applied automatically -- use `:PyreflyInfer` afterward if you like
  -- what you see.
  api.nvim_buf_create_user_command(bufnr, 'PyreflyInferPreview', function()
    local original_path = vim.api.nvim_buf_get_name(bufnr)
    if original_path == '' then
      vim.notify('Buffer has no file on disk to infer against', vim.log.levels.ERROR)
      return
    end
    local original_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local original_text = table.concat(original_lines, '\n')

    local ext = vim.fn.fnamemodify(original_path, ':e')
    local tmp = vim.fn.tempname() .. '.' .. (ext ~= '' and ext or 'py')
    vim.fn.writefile(original_lines, tmp)

    vim.notify('Running pyrefly infer preview...', vim.log.levels.INFO)
    run_infer_on_file(tmp, function(ok, err)
      if not ok then
        os.remove(tmp)
        vim.notify('pyrefly infer preview failed: ' .. tostring(err), vim.log.levels.ERROR)
        return
      end

      local inferred_lines = vim.fn.readfile(tmp)
      os.remove(tmp)
      local inferred_text = table.concat(inferred_lines, '\n')

      if inferred_text == original_text then
        vim.notify('pyrefly infer found nothing to add', vim.log.levels.INFO)
        return
      end

      local diff_result = vim.text.diff(original_text, inferred_text, {
        result_type = 'unified',
        ctxlen = 3,
      })
      local diff_text
      if type(diff_result) == 'string' then
        diff_text = diff_result
      else
        diff_text = '(no textual diff)'
      end

      local scratch = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(scratch, 0, -1, false, vim.split(diff_text, '\n'))
      vim.bo[scratch].filetype = 'diff'
      vim.bo[scratch].modifiable = false
      vim.bo[scratch].bufhidden = 'wipe'
      api.nvim_set_current_buf(scratch)
      vim.notify('Preview only -- run :PyreflyInfer to actually apply these changes', vim.log.levels.INFO)
    end)
  end, {
    desc = 'Preview pyrefly infer as a diff without touching the real file',
    force = true,
  })
end

---@type vim.lsp.Config
return {
  cmd = {
    'pyrefly',
    'lsp',
  },
  filetypes = {
    'python',
  },
  init_options = {
    pythonPath = default_python_path(),
  },
  on_attach = on_attach,
  root_markers = {
    '.git',
    'mypy.ini',
    'pyproject.toml',
    'pyrefly.toml',
    'requirements.txt',
    'setup.cfg',
    'setup.py',
  },
  settings = {
    python = {
      pythonPath = default_python_path(),
    },
    pyrefly = {
      python_interpreter = default_python_path(),
      displayTypeErrors = 'force-on',
      disableLanguageServices = false,
      extraPaths = {},
      analysis = {
        diagnosticMode = 'workspace',
        importFormat = 'absolute',
        inlayHints = {
          callArgumentNames = 'off',
          functionReturnTypes = true,
          pytestParameters = true,
          variableTypes = true,
        },
        showHoverGoToLinks = true,
      },
      disabledLanguageServices = {
        codeAction = false,
        completion = false,
        definition = false,
        declaration = false,
        documentHighlight = false,
        documentSymbol = false,
        hover = false,
        implementation = false,
        inlayHint = false,
        references = false,
        rename = false,
        semanticTokens = false,
        signatureHelp = false,
        typeDefinition = false,
      },
    },
  },
  on_exit = function(code, _, _)
    vim.notify('Closing Pyrefly LSP exited with code: ' .. code, vim.log.levels.INFO)
  end,
}
