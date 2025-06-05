-- ~/.config/nvim/lua/config/lang/python.lua  ──────────────────────────────────────────────
local M = {}
local dap = require("dap")
local null_ls = require("null-ls")
local b = null_ls.builtins
function M.get_config()
  return {
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
  }
end
function M.setup_dap()
  local dap = require("dap")
  dap.adapters.python = {
    type = "executable",
    command = "uv",
    args = { "run", "python", "-m", "debugpy.adapter" },
  }
  dap.configurations.python = {
    {
      type = "python",
      request = "launch",
      name = "Launch file",
      program = "${file}",
      pythonPath = function()
        local cwd = vim.fn.getcwd()
        return cwd .. "/.venv/bin/python"
      end,
    },
  }
  if pcall(require, "dap-python") then
    require("dap-python").setup("uv")
    require("dap-python").test_runner = "pytest"
  end
end
function M.setup_jupyter()
  require("quarto").setup({
    lspFeatures = {
      enabled = true,
      chunks = "curly",
      languages = { "r", "python", "julia", "bash", "html" },
      diagnostics = { enabled = true, triggers = { "BufWritePost" } },
      completion = { enabled = true },
    },
    codeRunner = {
      enabled = true,
      default_method = "molten",
      ft_runners = { python = "molten" },
    },
  })
  require("jupytext").setup({
    notebook_to_script_cmd = "jupytext --to py",
    script_to_notebook_cmd = "jupytext --to ipynb",
    style = "hydrogen",
    output_extension = "ipynb",
    force_ft = "python",
  })
  vim.g.jupyter_mapkeys = 0
  vim.keymap.set("n", "<leader>jr", "<cmd>JupyterRunFile<cr>", { desc = "Run Jupyter file" })
  vim.keymap.set("n", "<leader>jc", "<cmd>JupyterSendCell<cr>", { desc = "Send cell" })
  vim.keymap.set("n", "<leader>js", "<cmd>JupyterConnect<cr>", { desc = "Connect Jupyter" })
end
function M.setup_project_tools()
  vim.g.python3_host_prog = vim.fn.expand("~/.venv/nvim/bin/python")
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.py",
    callback = function()
      local root = vim.fn.findfile("pyproject.toml", vim.fn.getcwd() .. ";")
      if root ~= "" then
        local venv_py = vim.fn.fnamemodify(root, ":p:h") .. "/.venv/bin/python"
        if vim.fn.filereadable(venv_py) == 1 then
          vim.g.python3_host_prog = venv_py
        end
      end
    end,
  })
  vim.api.nvim_create_user_command("PoetryInstall", function()
    vim.fn.system("poetry install")
    vim.notify("Poetry deps installed", vim.log.levels.INFO)
  end, {})

  vim.api.nvim_create_user_command("PoetryUpdate", function()
    vim.fn.system("poetry update")
    vim.notify("Poetry deps updated", vim.log.levels.INFO)
  end, {})
end
function M.setup_telescope()
  local telescope = require("telescope")
  telescope.setup({
    extensions = {
      dap = {},
      symbols = { sources = { "python" } },
      repo = {
        list = {
          "fd",
          "-t",
          "d",
          "-H",
          "-I",
          ".git",
          vim.fn.getcwd(),
          "--exec",
          "dirname",
          "{}",
        },
      },
      frecency = {
        show_scores = true,
        show_unindexed = true,
        ignore_patterns = { "*.git/*", "*/tmp/*" },
        workspaces = { conf = "~/.config", project = "~/projects" },
      },
      import = { insert_at_top = true },
      conda = { anaconda_path = "/opt/miniconda3" },
    },
  })
  for _, ext in ipairs({
    "dap",
    "zoxide",
    "ui-select",
    "fzf",
    "repo",
    "frecency",
    "import",
    "conda",
  }) do
    pcall(telescope.load_extension, ext)
  end
end

function M.setup_notebook_detection()
  vim.api.nvim_create_autocmd("BufRead", {
    pattern = { "*.py", "*.ipynb", "*.mojo", "*.🔥" },
    callback = function()
      local ext = vim.fn.expand("%:e")
      if ext == "ipynb" then
        vim.b.is_jupyter_notebook = true
        vim.keymap.set("n", "<leader>x", "<cmd>JupyterSendCell<cr>", { buffer = true, desc = "Run cell" })
        vim.keymap.set("n", "<leader>X", "<cmd>JupyterSendAll<cr>", { buffer = true, desc = "Run all" })
        return
      end
      local markers = {
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
          vim.keymap.set("n", "<leader>x", "<cmd>" .. cmd .. "SendCell<cr>", { buffer = true })
          vim.keymap.set("n", "<leader>X", "<cmd>" .. cmd .. "SendAll<cr>", { buffer = true })
          break
        end
      end
    end,
  })
end
function M.setup_code_quality()
  null_ls.setup({
    sources = {
      b.formatting.isortd,
      b.formatting.blackd,
      b.code_actions.refactoring.with({ filetypes = { "python" } }),
      b.hover.dictionary.with({ filetypes = { "org", "text", "markdown" } }),
      b.completion.spell,
      b.diagnostics.pylint.with({
        extra_args = { "--from-stdin", "$FILENAME", "-f", "json" },
      }),
      b.diagnostics.mypy.with({
        extra_args = {
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
function M.setup_python()
  M.setup_dap()
  M.setup_jupyter()
  M.setup_notebook_detection()
  M.setup_project_tools()
  M.setup_telescope()
  M.setup_code_quality()
end
return M
