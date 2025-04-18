-- ~/.config/nvim/lua/config/scala.lua

local M = {}

function M.setup(on_attach, capabilities)
  local metals = require("metals")
  local metals_config = metals.bare_config()

  metals_config.init_options.statusBarProvider = "on"

  metals_config.settings = {
    showImplicitArguments = true,
    superMethodLensesEnabled = true,
    showInferredType = true,
    enableSemanticHighlighting = true,
    excludedPackages = { "akka.actor.typed.javadsl", "com.github.swagger.akka.javadsl" },
  }
  metals_config.capabilities = capabilities
  metals_config.on_attach = function(client, bufnr)
    if on_attach then
      on_attach(client, bufnr)
    end

    local function buf_set_keymap(...)
      vim.api.nvim_buf_set_keymap(bufnr, ...)
    end
    local opts = { noremap = true, silent = true }

    -- Scala LSP mappings
    buf_set_keymap("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
    buf_set_keymap("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
    buf_set_keymap("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
    buf_set_keymap("n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)

    -- Scala DAP mappings
    buf_set_keymap("n", "<F5>", "<cmd>lua require'dap'.continue()<CR>", opts)
    buf_set_keymap("n", "<F10>", "<cmd>lua require'dap'.step_over()<CR>", opts)
    buf_set_keymap("n", "<F11>", "<cmd>lua require'dap'.step_into()<CR>", opts)
    buf_set_keymap("n", "<F12>", "<cmd>lua require'dap'.step_out()<CR>", opts)
    buf_set_keymap("n", "<leader>db", "<cmd>lua require'dap'.toggle_breakpoint()<CR>", opts)
    buf_set_keymap("n", "<leader>sh", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
    buf_set_keymap("n", "<leader>dc", "<cmd>lua require'dap'.clear_breakpoints()<CR>", opts)
    buf_set_keymap("n", "<leader>dr", "<cmd>lua require'dap'.repl.open()<CR>", opts)

    -- Useful Metals commands
    buf_set_keymap("n", "<leader>mc", "<cmd>lua require('metals').commands()<CR>", opts)
    buf_set_keymap("n", "<leader>mi", "<cmd>lua require('metals').import_build()<CR>", opts)
    buf_set_keymap("n", "<leader>md", "<cmd>lua require('metals').doctor_run()<CR>", opts)
    buf_set_keymap("n", "<leader>mt", "<cmd>lua require('metals').tvp()<CR>", opts) -- Toggle parameter hints

    -- Scala workspace folder related mappings
    buf_set_keymap("n", "<leader>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
    buf_set_keymap("n", "<leader>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
    buf_set_keymap("n", "<leader>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", opts)
    buf_set_keymap("n", "<leader>oi", "<cmd>lua require('config.scala').organize_imports()<CR>", opts)

    -- Enable Tree View Protocol
    metals_config.settings.enableSemanticHighlighting = true

    -- DAP UI
    local dap = require("dap")
    local dapui = require("dapui")
    dapui.setup()

    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end
  end

  local group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "scala", "sbt", "java" },
    callback = function()
      metals.initialize_or_attach(metals_config)
    end,
    group = group,
  })
  vim.diagnostic.config({
    virtual_text = true,
    float = {
      source = "if_many",
      border = "rounded",
      header = "",
      prefix = "",
      format = function(diagnostic)
        local message = diagnostic.message
        local source = diagnostic.source or ""
        local code = diagnostic.code or ""

        if code ~= "" then
          return string.format("%s [%s] (%s)", message, code, source)
        else
          return string.format("%s (%s)", message, source)
        end
      end,
    },
  })

  -- Helper function that uses vim.notify instead of deprecated vim.api.nvim_err_writeln
  M.handle_error = function(module, error_message)
    local result = type(error_message) == "table" and vim.inspect(error_message) or error_message
    vim.notify("Error loading " .. module .. ":" .. result, vim.log.levels.ERROR)
  end
end
return M
