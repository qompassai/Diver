-- qompassai/Diver/lua/config/lang/python.lua
-- Qompass AI Diver Python Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'config.lang.python'
if vim.fn.has('nvim-0.11') == 1 then vim.opt.shortmess:append({ I = true }) end
local M = {}

function M.nls(opts)
  opts = opts or {}
  local nlsb = require('null-ls').builtins
  local sources = {
    nlsb.formatting.isortd,
    nlsb.formatting.blackd,
    nlsb.code_actions.refactoring.with({ filetypes = { 'python' } }),
    nlsb.hover.dictionary,
    nlsb.completion.spell,
    nlsb.diagnostics.pylint,
    nlsb.diagnostics.mypy.with({
      extra_args = opts.mypy_args or {
        '--ignore-missing-imports', '--disallow-untyped-defs',
        '--check-untyped-defs', '--warn-redundant-casts',
        '--no-implicit-optional'
      },
      cwd = function(params)
        return require('null-ls.utils').root_pattern('mypy.ini', '.mypy.ini')(params.bufname)
      end
    }),
  }
  return sources
end

function M.py_dap() ---@return nil
  local dap = require("dap")
  local dap_python = require("dap-python")
  local function get_pyenv_python_local()
    local cwd = vim.fn.getcwd()
    local f = io.open(cwd .. "/.python-version", "r")
    if not f then return nil end
    local version = f:read("*l")
    f:close()
    if version then
      local candidate = vim.fn.expand("~/.pyenv/versions/" .. version .. "/bin/python")
      if vim.fs_stat(candidate) then
        return candidate
      end
    end
    return nil
  end
  local resolved_python_path_cache = nil ---@type string|nil
  local function find_python()
    if resolved_python_path_cache then
      return resolved_python_path_cache
    end
    local cwd = vim.fn.getcwd()
    local venv = cwd .. "/.venv/bin/python"
    if vim.fs.exists(venv) then
      resolved_python_path_cache = venv
      return venv
    end
    local pyenv_local = get_pyenv_python_local() ---@type string|nil
    if pyenv_local then
      resolved_python_path_cache = pyenv_local
      return pyenv_local
    end
    local base = vim.fn.expand("~/.pyenv/versions/")
    local fs = vim.fs_scandir(base)
    if fs then
      while true do
        local name = vim.fs_scandir_next(fs)
        if not name then break end
        local python_candidate = base .. name .. "/bin/python"
        if vim.fs_stat(python_candidate) then
          resolved_python_path_cache = python_candidate
          return python_candidate
        end
      end
    end
    local sys_python = vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
    resolved_python_path_cache = sys_python
    return sys_python
  end
  dap.adapters.python = {
    type = "executable",
    command = "python",
    args = { "-m", "debugpy.adapter" },
  }
  dap.configurations.python = {
    {
      type = "python",
      request = "launch",
      name = "🐞 Launch file",
      program = "${file}",
      pythonPath = find_python,
    },
  }
  dap_python.setup(
    vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
  )
  dap_python.test_runner = "pytest"
end

function M.py_jupyter(opts)
  opts = opts or {}
  require('quarto').setup({
    lspFeatures = {
      enabled = opts.quarto_lsp ~= true,
      chunks = opts.quarto_chunks or 'curly',
      languages = opts.quarto_langs or
          { 'r', 'python', 'julia', 'bash', 'html' },
      diagnostics = {
        enabled = opts.quarto_diagnostics ~= false,
        triggers = opts.quarto_diag_triggers or { 'BufWritePost' }
      }
    },
    codeRunner = {
      enabled = opts.code_runner ~= true,
      default_method = opts.code_runner_method or 'molten',
      ft_runners = opts.code_runner_fts or { python = 'molten' }
    }
  })
  require('jupytext').setup({
    notebook_to_script_cmd = opts.jupytext_to_script or 'jupytext --to py',
    script_to_notebook_cmd = opts.jupytext_to_notebook or
        'jupytext --to ipynb',
    style = opts.jupytext_style or 'hydrogen',
    output_extension = opts.jupytext_ext or 'ipynb',
    force_ft = opts.jupytext_force_ft or 'python'
  })
end

function M.py_notebook_detection(opts)
  opts = opts or {}
  vim.api.nvim_create_autocmd('BufRead', {
    pattern = opts.patterns or { 'python', '*.ipynb', '*.mojo', '*.🔥' },
    callback = function()
      local ext = vim.fn.expand('%:e')
      if ext == 'ipynb' then
        vim.b.is_jupyter_notebook = true
        vim.keymap.set('n', opts.keys.run_cell or '<leader>jsc',
          '<cmd>JupyterSendCell<cr>', {
            buffer = true,
            desc = opts.desc_run_cell or 'Run cell'
          })
        vim.keymap.set('n', opts.keys.run_all or '<leader>jsa',
          '<cmd>JupyterSendAll<cr>', {
            buffer = true,
            desc = opts.desc_run_all or 'Run all'
          })
        return
      end
      local markers = opts.markers or
          {
            '^# %%', '^#%%', '^# In%[', '^// %%', '^//%%', '^// CELL'
          }
      for _, m in ipairs(markers) do
        if vim.fn.search(m, 'nw') > 0 then
          vim.b.has_jupyter_cells = true
          local cmd = (vim.bo.filetype == 'mojo') and 'Mojo' or
              'Jupyter'
          vim.keymap.set('n', opts.keys.run_cell or '<leader>x',
            '<cmd>' .. cmd .. 'SendCell<cr>',
            { buffer = true })
          vim.keymap.set('n', opts.keys.run_all or '<leader>X',
            '<cmd>' .. cmd .. 'SendAll<cr>',
            { buffer = true })
          break
        end
      end
    end
  })
end

---@param version? string
---@return string|nil
function M.get_pyenv_python(version)
  local base = vim.fn.expand("~/.pyenv/versions/")
  if version then
    local path = base .. version .. "/bin/python"
    if vim.fn.filereadable(path) == 1 then
      return path
    else
      return nil
    end
  end
  local pyenv_dirs = vim.fn.glob(base .. "*/", true, true)
  for _, dir in ipairs(pyenv_dirs) do
    local candidate = dir .. "bin/python"
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end
  return nil
end

function M.py_project_tools(opts) ---@return nil
  opts = opts or {}
  local resolved_python_cache = nil ---@type string|nil
  local function get_pyenv_python_local()
    local cwd = vim.fn.getcwd()
    local f = io.open(cwd .. "/.python-version", "r")
    if not f then return nil end
    local version = f:read("*l")
    f:close()
    if not version then return nil end
    local candidate = vim.fn.expand("~/.pyenv/versions/" .. version .. "/bin/python")
    if vim.fs_stat(candidate) then
      return candidate
    end
    return nil
  end
  local function get_pyenv_python_fallback()
    local base = vim.fn.expand("~/.pyenv/versions/")
    local pyenv_dirs = vim.fn.glob(base .. "*/", true, true)
    for _, dir in ipairs(pyenv_dirs) do
      local python_path = dir .. "bin/python"
      if vim.fn.filereadable(python_path) == 1 then
        return python_path
      end
    end
    return nil
  end
  local function find_python()
    if resolved_python_cache then
      return resolved_python_cache
    end
    local local_pyenv = get_pyenv_python_local() ---@type string|nil
    if local_pyenv then
      resolved_python_cache = local_pyenv
      return local_pyenv
    end
    local global_pyenv = get_pyenv_python_fallback()
    if global_pyenv then
      resolved_python_cache = global_pyenv
      return global_pyenv
    end
    local sys_python = vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
    resolved_python_cache = sys_python
    return sys_python
  end
  local default_python = opts.python_host_prog or find_python()
  vim.g.python3_host_prog = default_python
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.py",
    callback = function()
      local root = vim.fn.findfile("pyproject.toml", vim.fn.getcwd() .. ";")
      if root ~= "" then
        local pyenv_python = get_pyenv_python_local() ---@type string|nil
        if pyenv_python then
          vim.g.python3_host_prog = pyenv_python
          return
        end
      end
      vim.g.python3_host_prog = find_python()
    end,
  })
  if opts.enable_poetry then
    vim.api.nvim_create_user_command("PoetryInstall", function()
      vim.fn.system("poetry install")
      vim.notify("✅ Poetry dependencies installed", vim.log.levels.INFO)
    end, {})
    vim.api.nvim_create_user_command("PoetryUpdate", function()
      vim.fn.system("poetry update")
      vim.notify("♻️ Poetry dependencies updated", vim.log.levels.INFO)
    end, {})
  end
end

function M.py_venv(version)
  local base = vim.fn.expand("~/.pyenv/versions/")
  if version then
    local path = base .. version .. "/bin/python"
    return vim.fn.filereadable(path) == 1 and path or nil
  end
  local handle = io.popen("ls " .. base)
  if not handle then return nil end
  for line in handle:lines() do
    local path = base .. line .. "/bin/python"
    if vim.fn.filereadable(path) == 1 then
      handle:close()
      return path
    end
  end
  handle:close()
  return nil
end

function M.python_treesitter() ---@return table
  return {
    ensure_installed = { 'python' },
    highlight = {
      enable = true,
      disable = {},
    },
    indent = {
      enable = true,
    },
  }
end

function M.python_cfg(_, opts) ---@param opts table
  opts = opts or {}
  M.nls(opts)
  M.py_dap()
  M.py_jupyter(opts.jupyter)
  M.py_notebook_detection(opts.notebook)
  M.py_project_tools(opts.tools)
  M.get_pyenv_python()
end

return M
