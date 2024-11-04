return {
  "mfussenegger/nvim-dap",
  lazy = true,
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "mfussenegger/nvim-dap-python",
    "mfussenegger/nvim-lint",
    "mfussenegger/nvim-treehopper",
    "mfussenegger/nvim-ansible",
    "mfussenegger/nvim-snippasta",
    "theHamsta/nvim-dap-virtual-text",
  },
  config = function()
    local dap = require "dap"
    local dapui = require "dapui"
    local dap_virtual_text = require "nvim-dap-virtual-text"
    print(dapui)

    -- DAP UI Setup
    dapui.setup()
    dap_virtual_text.setup()

    require("nvim-dap-virtual-text").setup {
      display_callback = function(variable)
        local name = string.lower(variable.name)
        local value = string.lower(variable.value)
        if name:match "secret" or name:match "api" or value:match "secret" or value:match "api" then
          return "*****"
        end
        if #variable.value > 15 then
          return " " .. string.sub(variable.value, 1, 15) .. "... "
        end
        return " " .. variable.value
      end,
    }

    -- DAP Listeners for UI
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end

    -- Python Debug Adapter (Debugpy)
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

    -- Rust Debug Adapter (LLDB)
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
          return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = {},
        runInTerminal = true,
      },
    }

    -- Java Debug Adapter (Java Debug Server)
    dap.adapters.java = {
      type = "server",
      host = "127.0.0.1",
      port = 5005,
    }
    dap.configurations.java = {
      {
        type = "java",
        request = "attach",
        name = "Attach to the process",
        hostName = "127.0.0.1",
        port = 5005,
      },
    }

    dap.configurations.javascript = {
      {
        name = "Launch file",
        type = "node2",
        request = "launch",
        program = "${file}",
        cwd = vim.fn.getcwd(),
        sourceMaps = true,
        protocol = "inspector",
        console = "integratedTerminal",
      },
    }
    dap.configurations.typescript = dap.configurations.javascript
    dap.configurations.javascript[1].env = {
      NODE_ENV = "development",
      DEBUG = "node:*",
    }
  end,
  --[[
-- [{
  "nvim-neotest/neotest",
  lazy = true,
  dependencies = { "nvim-neotest/neotest-python" },
  config = function()
    ---@diagnostic disable-next-line: missing-fields
    require("neotest").setup {
      adapters = {
        require "neotest-python",
      },
    }
  end,
  keys = {
    { "<leader>dtt", ":lua require'neotest'.run.run({strategy = 'dap'})<cr>", desc = "[t]est" },
    { "<leader>dts", ":lua require'neotest'.run.stop()<cr>", desc = "[s]top test" },
    { "<leader>dta", ":lua require'neotest'.run.attach()<cr>", desc = "[a]ttach test" },
    { "<leader>dtf", ":lua require'neotest'.run.run(vim.fn.expand('%'))<cr>", desc = "test [f]ile" },
    { "<leader>dts", ":lua require'neotest'.summary.toggle()<cr>", desc = "test [s]ummary" },
  },
-- }]
--]]
}
