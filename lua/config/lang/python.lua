-- ~/.config/nvim/lua/config/lang/python.lua  ──────────────────────────────────────────────
if vim.fn.has("nvim-0.11") == 1 then
  vim.g.python3_host_prog = vim.fn.expand("~/.venv/nvim/bin/python")
  vim.opt.shortmess:append({ I = true })
end
local M = {}
local dap = require("dap")
local null_ls = require("null-ls")
local b = null_ls.builtins
function M.py_code_quality(opts)
  opts = opts or {}
  null_ls.setup({
    sources = {
      b.formatting.isortd,
      b.formatting.blackd,
      b.code_actions.refactoring.with({ filetypes = { "python" } }),
      b.hover.dictionary.with({ filetypes = opts.dict_filetypes or { "org", "text", "markdown" } }),
      b.completion.spell,
      b.diagnostics.pylint.with({
        extra_args = opts.pylint_args or { "--from-stdin", "$FILENAME", "-f", "json" },
      }),
      b.diagnostics.mypy.with({
        extra_args = opts.mypy_args or {
          "--ignore-missing-imports",
          "--disallow-untyped-defs",
          "--check-untyped-defs",
          "--warn-redundant-casts",
          "--no-implicit-optional",
        },
        cwd = function(params)
          return require("null-ls.utils").root_pattern("mypy.ini", ".mypy.ini")(params.bufname)
        end,
      }),
    },
    on_attach = function(client, bufnr)
      if client.supports_method("textDocument/formatting") then
        vim.api.nvim_create_autocmd("BufWritePre", {
          buffer = bufnr,
          callback = function()
            vim.lsp.buf.format({ bufnr = bufnr })
          end,
        })
      end
    end,
  })
end
function M.py_dap(opts)
  opts = opts or {}
  dap.adapters.python = {
    type = "executable",
    command = opts.dap_command or "uv",
    args = opts.dap_args or { "run", "python", "-m", "debugpy.adapter" },
  }
  dap.configurations.python = {
    {
      type = "python",
      request = "launch",
      name = opts.launch_name or "Launch file",
      program = "${file}",
      pythonPath = opts.pythonPath or function()
        local versions = {"313", "312", "314", "311"}
        for _, version in ipairs(versions) do
          local venv_path = vim.fn.expand("~/.diver/.python/.venv" .. version) .. "/bin/python"
          if vim.fn.filereadable(venv_path) == 1 then
            return venv_path
          end
        end
        local project_python = vim.fn.getcwd() .. "/.venv/bin/python"
        if vim.fn.filereadable(project_python) == 1 then
          return project_python
        end
        return vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
      end,
    }
  }
  if pcall(require, "dap-python") then
    require("dap-python").setup(opts.dap_python_path or "uv")
    require("dap-python").test_runner = opts.test_runner or "pytest"
  end
end
function M.py_fzf(opts)
  opts = opts or {}
  local fzf = require("fzf-lua")
  fzf.setup({
    winopts = {
      width = 0.95,
      height = 0.85,
      preview = {
        hidden = "hidden",
      },
    },
    files = {
      cmd = opts.files_cmd or [[fd --type f --hidden --follow --exclude .git]],
      file_icons = true,
      color_icons = true,
    },
    dap = opts.dap or {
      breakpoints = {
        mappings = {
          n = {
            ["<cr>"] = "toggle_breakpoint",
          },
        },
      },
    },
    conda = opts.conda or {
      anaconda_path = opts.conda_path or "/opt/miniconda3",
      prompt = "Conda❯ ",
    },
    fzf_opts = {
      ["--tiebreak"] = "index",
    },
    custom_providers = {
      symbols = function(query)
        return require("fzf-lua.providers.symbols")(query, {
          symbols = { "python" },
          file_icons = true,
        })
      end,
      imports = {
        cmd = [[rg --vimgrep --type py '^import|^from']],
        actions = {
          ["default"] = require("fzf-lua.actions").file_edit,
        },
      },
    },
    keymap = {
      builtin = {
        ["<C-d>"] = "preview-page-down",
        ["<C-u>"] = "preview-page-up",
      },
    },
  })
end
function M.py_jupyter(opts)
  opts = opts or {}
  require("quarto").setup({
    lspFeatures = {
      enabled = opts.quarto_lsp ~= false,
      chunks = opts.quarto_chunks or "curly",
      languages = opts.quarto_langs or { "r", "python", "julia", "bash", "html" },
      diagnostics = {
        enabled = opts.quarto_diagnostics ~= false,
        triggers = opts.quarto_diag_triggers or { "BufWritePost" },
      },
    },
    codeRunner = {
      enabled = opts.code_runner ~= false,
      default_method = opts.code_runner_method or "molten",
      ft_runners = opts.code_runner_fts or { python = "molten" },
    },
  })
  require("jupytext").setup({
    notebook_to_script_cmd = opts.jupytext_to_script or "jupytext --to py",
    script_to_notebook_cmd = opts.jupytext_to_notebook or "jupytext --to ipynb",
    style = opts.jupytext_style or "hydrogen",
    output_extension = opts.jupytext_ext or "ipynb",
    force_ft = opts.jupytext_force_ft or "python",
  })
end
function M.py_notebook_detection(opts)
  opts = opts or {}
  vim.api.nvim_create_autocmd("BufRead", {
    pattern = opts.patterns or { "*.py", "*.ipynb", "*.mojo", "*.🔥" },
    callback = function()
      local ext = vim.fn.expand("%:e")
      if ext == "ipynb" then
        vim.b.is_jupyter_notebook = true
        vim.keymap.set("n", opts.keys.run_cell or "<leader>x", "<cmd>JupyterSendCell<cr>", {
          buffer = true,
          desc = opts.desc_run_cell or "Run cell",
        })
        vim.keymap.set("n", opts.keys.run_all or "<leader>X", "<cmd>JupyterSendAll<cr>", {
          buffer = true,
          desc = opts.desc_run_all or "Run all",
        })
        return
      end
      local markers = opts.markers
        or {
          "^# %%",
          "^#%%",
          "^# In%[",
          "^// %%",
          "^//%%",
          "^// CELL",
        }
      for _, m in ipairs(markers) do
        if vim.fn.search(m, "nw") > 0 then
          vim.b.has_jupyter_cells = true
          local cmd = (vim.bo.filetype == "mojo") and "Mojo" or "Jupyter"
          vim.keymap.set("n", opts.keys.run_cell or "<leader>x", "<cmd>" .. cmd .. "SendCell<cr>", { buffer = true })
          vim.keymap.set("n", opts.keys.run_all or "<leader>X", "<cmd>" .. cmd .. "SendAll<cr>", { buffer = true })
          break
        end
      end
    end,
  })
end
function M.py_project_tools(opts)
  opts = opts or {}
  local function get_diver_venv_path()
    local versions = {"313", "312", "314", "311"}
    for _, v in ipairs(versions) do
      local path = vim.fn.expand("~/.diver/.python/.venv" .. v) .. "/bin/python"
      if vim.fn.filereadable(path) == 1 then
        return path
      end
    end
    return nil
  end
  vim.g.python3_host_prog = opts.python_host_prog
                            or get_diver_venv_path()
                            or vim.fn.expand("~/.venv/nvim/bin/python")
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.py",
    callback = function()
      local root = vim.fn.findfile("pyproject.toml", vim.fn.getcwd() .. ";")
      if root ~= "" then
        local proj_venv = vim.fn.fnamemodify(root, ":p:h") .. "/.venv/bin/python"
        if vim.fn.filereadable(proj_venv) == 1 then
          vim.g.python3_host_prog = proj_venv
          return
        end
      end
      local diver_venv = get_diver_venv_path()
      if diver_venv then
        vim.g.python3_host_prog = diver_venv
      end
    end,
  })
  if opts.enable_poetry then
    vim.api.nvim_create_user_command("PoetryInstall", function()
      vim.fn.system("poetry install")
      vim.notify("Poetry deps installed", vim.log.levels.INFO)
    end, {})
    vim.api.nvim_create_user_command("PoetryUpdate", function()
      vim.fn.system("poetry update")
      vim.notify("Poetry deps updated", vim.log.levels.INFO)
    end, {})
  end
end
function M.py_venv(version)
  local versions = {
    "311", "312", "313", "314"
  }
   if not version then
    for _, v in ipairs(versions) do
      local path = vim.fn.expand("~/.diver/.python/.venv" .. v) .. "/bin/python"
      if vim.fn.filereadable(path) == 1 then
        return path
      end
    end
    return nil
  end
  local path = vim.fn.expand("~/.diver/.python/.venv" .. version) .. "/bin/python"
  return vim.fn.filereadable(path) == 1 and path or nil
end
function M.py_pyright(opts)
  opts = opts or {}
  return {
    on_new_config = function(new_config)
      local diver_python = M.py_venv()
      if diver_python then
        new_config.settings.python.pythonPath = diver_python
        return
      end
      local venv = vim.fn.finddir(".venv*", vim.fn.getcwd() .. ";", 1)
      if venv ~= "" then
        local python_path = venv .. "/bin/python"
        if vim.fn.executable(python_path) == 1 then
          new_config.settings.python.pythonPath = python_path
        end
      end
    end,
    settings = {
      python = {
        analysis = {
          typeCheckingMode = opts.typeCheckingMode or "strict",
          diagnosticMode = opts.diagnosticMode or "openFilesOnly",
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          diagnosticSeverityOverrides = opts.diagnosticSeverityOverrides or {
            reportUnusedImport = "warning",
            reportUnusedVariable = "warning",
            reportUnusedClass = "warning",
          },
          strictListInference = true,
          strictDictionaryInference = true,
          strictSetInference = true,
          strictParameterNoneValue = true,
          autoImportCompletions = true,
          importFormat = opts.importFormat or "absolute",  -- or "relative"
          stubPath = opts.stubPath or "typings",
          inlayHints = {
            variableTypes = opts.variableTypesInlay or true,
            functionReturnTypes = opts.functionReturnTypesInlay or true,
            callArgumentNames = opts.callArgumentNames or "all",  -- "none", "literals", "all"
            pytestParameters = true,
          },
          logLevel = opts.logLevel or "Information",  -- "Error", "Warning", "Information", "Trace"
          typeEvaluationMode = "standard",  -- or "high"
          indexing = true,
        },
        workspace = {
          symbolIndex = true,
          symbolMaxWorkspace = 5000,
          enableSourceMap = true,
        },
        venvPath = vim.fn.expand("~/.diver/.python"),
        venv = ".",
      },
    },
    capabilities = {
      workspace = {
        fileOperations = {
          didRename = true,
          willRename = true,
        },
      },
    },
    before_init = function(_, config)
      config.settings.python.analysis.typeInformationMode = "standard"
    end,
  }
end
function M.setup_python(opts)
  opts = opts or {}
  M.py_code_quality(opts.linting)
  M.py_dap(opts.dap)
  M.py_fzf(opts.fzf)
  M.py_jupyter(opts.jupyter)
  M.py_notebook_detection(opts.notebook)
  M.py_project_tools(opts.tools)
  M.py_pyright(opts)
end
return M
