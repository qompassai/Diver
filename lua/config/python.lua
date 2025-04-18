-- ~/.config/nvim/config/python.lua
local M = {}
local unpack = table.unpack or unpack

function M.setup(on_attach, capabilities)
  require("lspconfig").pyright.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    settings = {
      python = {
        analysis = {
          typeCheckingMode = "basic",
          diagnosticMode = "workspace",
          inlayHints = {
            variableTypes = true,
            functionReturnTypes = true,
          },
        },
      },
    },
  })
  vim.lsp.enable("pyright")
  local dap = require("dap")
  dap.adapters.python = {
    type = "executable",
    command = "python",
    args = { "-m", "debugpy.adapter" },
  }
  dap.configurations.python = {
    {
      type = "python",
      request = "launch",
      name = "Launch file",
      program = "${file}",
      pythonPath = function()
        return "/usr/bin/python3"
      end,
    },
  }
  local ok, dap_python = pcall(require, "dap-python")
  if ok then
    dap_python.setup("~/.virtualenvs/debugpy/bin/python")
    dap_python.test_runner = "pytest"
  else
    vim.notify("nvim-dap-python not found", vim.log.levels.WARN)
  end
  dap.test_runner = "pytest"
end
function M.setup_jupyter()
  require("quarto").setup({
    debug = false,
    closePreviewOnExit = true,
    lspFeatures = {
      enabled = true,
      chunks = "curly",
      languages = { "r", "python", "julia", "bash", "html" },
      diagnostics = {
        enabled = true,
        triggers = { "BufWritePost" },
      },
      completion = { enabled = true },
    },
    codeRunner = {
      enabled = true,
      default_method = "molten", -- Options: "molten", "slime", "iron"
      ft_runners = { python = "molten" },
    },
  })
end
require("jupynium").setup({
  jupyter_command = "jupyter",
  notebook_dir = "~/notebooks",
  auto_start_server = {
    enable = true,
    file_pattern = { "*.ipynb" },
  },
})
require("jupytext").setup({
  notebook_to_script_cmd = "jupytext --to py",
  script_to_notebook_cmd = "jupytext --to ipynb",
  style = "hydrogen",
  output_extension = "ipynb",
  force_ft = "python",
})
require("jupynium").setup({
  jupyter_command = "jupyter",
  notebook_dir = "~/notebooks",
  auto_start_server = {
    enable = true,
    file_pattern = { "*.ipynb" },
  },
  default_notebook_URL = "localhost:8888/nbclassic",
})

vim.g.jupyter_mapkeys = 0

vim.keymap.set("n", "<leader>jr", "<cmd>JupyterRunFile<cr>", { desc = "Run Jupyter File" })
vim.keymap.set("n", "<leader>jc", "<cmd>JupyterSendCell<cr>", { desc = "Send Jupyter Cell" })
vim.keymap.set("n", "<leader>jj", "<cmd>JupyniumStartAndAttachToServer<cr>", { desc = "Start Jupynium" })
vim.keymap.set("n", "<leader>js", "<cmd>JupyterConnect<cr>", { desc = "Connect to Jupyter" })

require("dressing").setup({
  input = {
    default_prompt = "> ",
  },
  select = {
    backend = { "telescope", "fzf", "builtin" },
  },
})

vim.filetype.add({
  extension = {
    ipynb = "jupyter",
  },
  pattern = {
    [".*%.sync%.py"] = "python",
  },
})
function M.setup_project_tools()
  vim.g.python3_host_prog = vim.fn.exepath("python3")
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.py",
    callback = function()
      local venv = vim.fn.findfile("pyproject.toml", vim.fn.getcwd() .. ";")
      if venv ~= "" then
        local venv_path = vim.fn.fnamemodify(venv, ":p:h") .. "/.venv/bin/python"
        if vim.fn.filereadable(venv_path) == 1 then
          vim.g.python3_host_prog = venv_path
        end
      end
    end,
  })
  vim.api.nvim_create_user_command("PoetryInstall", function()
    vim.fn.system("poetry install")
    vim.notify("Poetry dependencies installed", vim.log.levels.INFO)
  end, {})
  vim.api.nvim_create_user_command("PoetryUpdate", function()
    vim.fn.system("poetry update")
    vim.notify("Poetry dependencies updated", vim.log.levels.INFO)
  end, {})
end
function M.setup_telescope()
  local telescope = require("telescope")
  telescope.setup({
    extensions = {
      dap = {},
      symbols = {
        sources = { "python" },
      },
      repo = {
        list = { "fd", "-t", "d", "-H", "-I", ".git", vim.fn.getcwd(), "--exec", "dirname", "{}" },
      },
      frecency = {
        show_scores = true,
        show_unindexed = true,
        ignore_patterns = { "*.git/*", "*/tmp/*" },
        workspaces = {
          ["conf"] = "/home/$USER/.config",
          ["project"] = "/home/$USER/projects",
        },
      },
      import = {
        insert_at_top = true,
      },
      conda = {
        anaconda_path = "/opt/miniconda3",
      },
    },
  })
  local function safe_load_extension(extension_name)
    local status_ok, _ = pcall(telescope.load_extension, extension_name)
    if not status_ok then
      vim.notify("Telescope extension '" .. extension_name .. "' not found or failed to load", vim.log.levels.WARN)
    end
  end
  safe_load_extension("dap")
  safe_load_extension("zoxide")
  safe_load_extension("ui-select")
  safe_load_extension("fzf")
  safe_load_extension("repo")
  safe_load_extension("frecency")
  safe_load_extension("import")
  safe_load_extension("conda")
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local find_python_modules = function()
    local command = "python -c 'import sys; print(\"\\n\".join(sys.path))'"
    local handle = io.popen(command)
    if not handle then
      vim.notify("Failed to execute Python command", vim.log.levels.ERROR)
      return
    end
    local result = handle:read("*a")
    if not result then
      handle:close()
      vim.notify("Failed to read Python path information", vim.log.levels.ERROR)
      return
    end
    local success, close_err = handle:close()
    if not success then
      vim.notify("Error closing handle: " .. (close_err or "unknown error"), vim.log.levels.WARN)
    end
    local paths = {}
    for path in string.gmatch(result, "[^\n]+") do
      if path ~= "" and vim.fn.isdirectory(path) == 1 then
        table.insert(paths, path)
      end
    end
    if #paths == 0 then
      vim.notify("No valid Python module paths found", vim.log.levels.WARN)
      return
    end
    pickers
      .new({}, {
        prompt_title = "Python Modules",
        finder = finders.new_oneshot_job({ "find", unpack(paths), "-name", "*.py", "-o", "-name", "*.so" }, {}),
        sorter = conf.generic_sorter({}),
      })
      :find()
  end
  vim.api.nvim_create_user_command("TelescopePythonModules", find_python_modules, {})
end

function M.setup_notebook_detection()
  vim.api.nvim_create_autocmd("BufRead", {
    pattern = "*.py",
    callback = function()
      local has_cell_markers = vim.fn.search("^# %%", "nw") > 0
      if has_cell_markers then
        vim.b.has_jupyter_cells = true
        vim.keymap.set("n", "<leader>x", "<cmd>JupyterSendCell<cr>", { buffer = true, desc = "Run Cell" })
        vim.keymap.set("n", "<leader>X", "<cmd>JupyterSendAll<cr>", { buffer = true, desc = "Run All Cells" })
      end
    end,
  })
end
function M.setup_code_quality()
  local null_ls = require("null-ls")
  local bandit = {
    name = "bandit",
    method = null_ls.methods.DIAGNOSTICS,
    filetypes = { "python" },
    generator = null_ls.generator({
      command = "bandit",
      args = { "-f", "json", "--quiet", "-" },
      to_stdin = true,
      from_stderr = true,
      format = "json",
      on_output = function(params)
        local diagnostics = {}
        local output = params.output
        if not output then
          return diagnostics
        end
        for _, issue in ipairs(output.results or {}) do
          table.insert(diagnostics, {
            row = issue.line_number,
            col = 1,
            message = issue.issue_text,
            severity = vim.diagnostic.severity.WARN,
          })
        end
        return diagnostics
      end,
    }),
  }
  local sources = {
    null_ls.builtins.formatting.black,
    null_ls.builtins.formatting.isort,
    null_ls.builtins.diagnostics.mypy,
    null_ls.builtins.code_actions.refactoring,
    null_ls.builtins.hover.dictionary,
    null_ls.builtins.completion.spell,
    null_ls.builtins.diagnostics.pylint.with({
      extra_args = { "--disable=C0111", "--disable=C0103" },
    }),
    null_ls.builtins.diagnostics.mypy.with({
      extra_args = { "--ignore-missing-imports", "--disallow-untyped-defs" },
    }),
    bandit,
  }
  null_ls.setup({
    sources = sources,
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
  null_ls.register(sources)
  vim.api.nvim_create_user_command("PythonLint", function()
    vim.cmd("lua vim.lsp.buf.format()")
    vim.cmd("write")
    vim.notify("Python code linted and formatted", vim.log.levels.INFO)
  end, {})
end

function M.setup_testing()
  local pytest_cmd = "pytest"
  local function run_pytest_file()
    local file = vim.fn.expand("%:p")
    vim.cmd("split | terminal " .. pytest_cmd .. " " .. file)
  end
  local function run_pytest_function()
    local file = vim.fn.expand("%:p")
    local cmd = pytest_cmd .. " " .. file .. "::" .. vim.fn.expand("<cword>") .. " -v"
    vim.cmd("split | terminal " .. cmd)
  end
  vim.api.nvim_create_user_command("PyTestFile", run_pytest_file, {})
  vim.api.nvim_create_user_command("PyTestFunc", run_pytest_function, {})
end
function M.setup_all()
  M.setup()
  M.setup_jupyter()
  M.setup_notebook_detection()
  M.setup_project_tools()
  M.setup_telescope()
  M.setup_code_quality()
  M.setup_testing()
end

return M
