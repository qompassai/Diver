-- ~/.config/nvim/lua/config/zig.lua
local dap = require("dap")
local lspconfig = require("lspconfig")

local M = {}

function M.setup(on_attach, capabilities)
  lspconfig.zls.setup({
    capabilities = capabilities,
    cmd = { "/usr/bin/zls" },
    filetypes = { "zig", "zir", "zon" },
    root_dir = lspconfig.util.root_pattern("zls.json", "build.zig", ".git"),
    single_file_support = true,
    settings = {
      zls = {
        semantic_tokens = "full",
        enable_inlay_hints = true,
        inlay_hints_show_builtin = true,
        inlay_hints_exclude_single_argument = true,
        inlay_hints_hide_redundant_param_names = true,
        inlay_hints_hide_redundant_param_names_last_token = true,
        enable_autofix = true,
        zig_exe_path = "/usr/bin/zig",
        zig_lib_path = "/usr/lib/zig",
        enable_build_on_save = true,
        build_runner_path = "/usr/bin/zig",
        warn_style = true,
        warn_undocumented = true,
        operator_completions = true,
        use_comptime_interpreter = true,
        dangerous_comptime_experiments_do_not_enable = false,
        highlight_global_var_declarations = true,
        dangerous_comptime_interpreter_behavior_override = "default",
        record_session = false,
      },
    },
    on_attach = function(client, bufnr)
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format({ bufnr = bufnr })
        end,
      })

      local opts = { noremap = true, silent = true, buffer = bufnr }
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
      vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
      vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
      vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
      vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, opts)
      vim.keymap.set("n", "<space>ca", vim.lsp.buf.code_action, opts)
      vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
      if type(on_attach) == "function" then
        on_attach(client, bufnr)
      end
    end,
  })

  -- Configure DAP
  dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
      command = "codelldb",
      args = { "--port", "${port}" },
    },
  }

  dap.adapters.lldb = {
    type = "executable",
    command = "/usr/bin/lldb",
    name = "lldb",
  }

  dap.configurations.zig = {
    {
      name = "Launch",
      type = "lldb",
      request = "launch",
      program = "${workspaceFolder}/zig-out/bin/${workspaceFolderBasename}",
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
      runInTerminal = true,
      terminal = "integrated",
    },
    {
      name = "Debug Zig Tests",
      type = "codelldb",
      request = "launch",
      program = "${workspaceFolder}/zig-out/bin/test",
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
    },
  }

  vim.keymap.set("n", "<F5>", function()
    dap.continue()
  end, { desc = "Debug: Continue" })
  vim.keymap.set("n", "<F10>", function()
    dap.step_over()
  end, { desc = "Debug: Step Over" })
  vim.keymap.set("n", "<F11>", function()
    dap.step_into()
  end, { desc = "Debug: Step Into" })
  vim.keymap.set("n", "<F12>", function()
    dap.step_out()
  end, { desc = "Debug: Step Out" })
  vim.keymap.set("n", "<leader>b", function()
    dap.toggle_breakpoint()
  end, { desc = "Debug: Toggle Breakpoint" })
  vim.keymap.set("n", "<leader>dr", function()
    dap.repl.open()
  end, { desc = "Debug: Open REPL" })
end

return M
