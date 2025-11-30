-- /qompassai/Diver/lsp/gofumpt.lua
-- Qompass AI Go Formatter LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config["gofumpt"] = {
  cmd = {
    "gofumpt",
  },
  filetypes = {
    "go",
  },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    gofumpt = {
      extra_args = {},
    },
  },
  on_attach = function(client, bufnr)
    local _ = client ---@diagnostic disable-line: unused-local
    local function run_gofumpt()
      bufnr = bufnr or vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("write")
      end)
      local filename = vim.api.nvim_buf_get_name(bufnr)
      if filename == "" then
        vim.notify("gofumpt: buffer has no name", vim.log.levels.WARN)
        return
      end
      vim.fn.jobstart({ "gofumpt", "-w", filename }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_exit = function(_, code)
          if code == 0 then
            vim.schedule(function()
              if vim.api.nvim_buf_is_loaded(bufnr) then
                vim.cmd("edit!")
              end
            end)
          else
            vim.notify("gofumpt: formatting failed", vim.log.levels.ERROR)
          end
        end,
        on_stderr = function(_, err)
          if err and err[1] and err[1] ~= "" then
            vim.notify("gofumpt: " .. table.concat(err, "\n"), vim.log.levels.ERROR)
          end
        end,
      })
    end
    vim.keymap.set("n", "<leader>gf", run_gofumpt, { buffer = bufnr, desc = "Format Go with gofumpt" })
  end,
}
