-- /qompassai/Diver/lsp/sqruff.lua
-- Qompass AI SQL Ruff LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- Reference: https://github.com/quarylabs/sqruff?tab=readme-ov-file#installation
-- Install: cargo install sqruff
vim.lsp.config["sqruff"] = {
  cmd = {
    "sqruff",
  },
  filetypes = {
    "sql",
  },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    sqruff = {},
  },
  on_attach = function(client, bufnr)
    local _ = client ---@diagnostic disable-line: unused-local
    local function format_sqruff()
      bufnr = bufnr or vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("write")
      end)
      local filename = vim.api.nvim_buf_get_name(bufnr)
      if filename == "" then
        vim.notify("sqruff: buffer has no name", vim.log.levels.WARN)
        return
      end
      vim.fn.jobstart({
        "sqruff",
        "format",
        filename,
      }, {
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
            vim.notify("sqruff: formatting failed", vim.log.levels.ERROR)
          end
        end,
        on_stderr = function(_, err)
          if err and err[1] and err[1] ~= "" then
            vim.notify("sqruff: " .. table.concat(err, "\n"), vim.log.levels.ERROR)
          end
        end,
      })
    end
    local function lint_sqruff()
      bufnr = bufnr or vim.api.nvim_get_current_buf()
      local filename = vim.api.nvim_buf_get_name(bufnr)
      if filename == "" then
        vim.notify("sqruff: buffer has no name", vim.log.levels.WARN)
        return
      end
      vim.fn.jobstart({
        "sqruff",
        "lint",
        "--format",
        "json",
        filename,
      }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
          if not data or #data == 0 then
            return
          end
          local ok, decoded = pcall(vim.json.decode, table.concat(data, "\n"))
          if not ok or not decoded then
            vim.notify("sqruff: failed to parse lint output", vim.log.levels.ERROR)
            return
          end
          local issues = {}
          if type(decoded) == "table" then
            if decoded[1] ~= nil then
              issues = decoded
            else
              issues = { decoded }
            end
          end
          local qf = {}
          for _, issue in ipairs(issues) do
            table.insert(qf, {
              filename = issue.path or filename,
              lnum = issue.line or 1,
              col = issue.column or 1,
              text = (issue.rule or "SQRUFF") .. ": " .. (issue.message or ""),
              type = (issue.severity == "error") and "E" or "W",
            })
          end
          if #qf > 0 then
            vim.fn.setqflist(qf, "r")
            vim.cmd("copen")
          else
            vim.notify("sqruff: no issues", vim.log.levels.INFO)
          end
        end,
        on_stderr = function(_, err)
          if err and err[1] and err[1] ~= "" then
            vim.notify("sqruff: " .. table.concat(err, "\n"), vim.log.levels.ERROR)
          end
        end,
      })
    end
  end,
}
