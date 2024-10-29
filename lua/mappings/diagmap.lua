local diagmap = {}

local map = vim.keymap.set

-- Nerd Legend (Simplified)

-- Breakpoint: Pause the execution of the code at a specified line.
-- Continue: Resume the execution of a paused debugging session.
-- DAP REPL: A console to interact with the debugger, similar to an interactive shell.
-- Diagnostics: Messages that provide information about issues in the code.
-- In-file: Refers to actions that apply only to the current file or buffer.
-- LSP: Language Server Protocol, provides editor features like code completion, diagnostics, etc.
-- Location List: A window showing errors or search results specific to the current file.
-- None-ls: A plugin used for handling diagnostics, formatting, and other editor actions.
-- Quickfix List: A list containing errors or search results across multiple files.
-- REPL: A tool to interactively run code line by line (Read-Eval-Print Loop).
-- Step Into: Step into a function or block to see its internal execution.
-- Step Out: Step out of the current function or block to return to the caller.
-- Step Over: Step over a line, executing it without going into functions.
-- Symbol: Elements in your code like functions, variables, or classes.
-- Toggle: Turn a feature on or off.
-- Trouble: A plugin for managing diagnostics, errors, and quickfix lists visually.
-- UI: User Interface, components that visually represent information.

-- None-ls mappings

-- Toggle null-ls diagnostics
map("n", "<leader>dn", function()
  local null_ls = require "null-ls"
  local method = require("null-ls").methods.DIAGNOSTICS
  local active_sources = null_ls.get_sources()

  -- Check if any diagnostics source is currently enabled
  local diagnostics_enabled = false
  for _, source in ipairs(active_sources) do
    if source.method == method and source.enabled then
      diagnostics_enabled = true
      break
    end
  end

  if diagnostics_enabled then
    null_ls.disable { method = method }
    print "null-ls diagnostics disabled"
  else
    null_ls.enable { method = method }
    print "null-ls diagnostics enabled"
  end
end, { desc = "None-ls [d]iagnostic [n]ull-ls toggle on or off" })

-- Trouble diagnostics toggle
map("n", "<leader>Td", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Trouble toggle Diag Window" })
-- In normal mode, press 'Space' + 'T' + 'd' to toggle the Trouble diagnostics window

-- Toggle Trouble diagnostics for the current buffer only
map("n", "<leader>Tb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Trouble toggle in-file" })
-- In normal mode, press 'Space' + 'T' + 'b' to toggle Trouble diagnostics for the current buffer

-- Toggle Trouble symbols window without focusing
map("n", "<leader>Ts", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Trouble toggle symbols" })
-- In normal mode, press 'Space' + 'T' + 'b' to toggle the Trouble symbols window without changing focus

-- Toggle Trouble LSP window on the right side without focusing
map("n", "<leader>Tw", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", { desc = "Trouble [T]oggle LSP [w]indow" })
-- In normal mode, press 'Space' + 'T' + 'w' to toggle the Trouble LSP window on the right side without changing focus

-- Toggle Trouble location list
map("n", "<leader>Tl", "<cmd>Trouble loclist toggle<cr>", { desc = "Trouble [T]oggle [l]ist" })
-- In normal mode, press 'Space' + 'T' + 'l' to toggle the Trouble location list

-- Toggle Trouble quickfix list
map("n", "<leader>Tq", "<cmd>Trouble qflist toggle<cr>", { desc = "Trouble [t]oggle [q]uickfix list" })
-- In normal mode, press 'Space' + 'T' + 'q' to toggle the Trouble quickfix list

-- Start debugging session
map("n", "<leader>ds", "<cmd>lua require'dap'.continue()<CR>", { desc = "Nvim-Dap Start debugging session" })
-- In normal mode, press 'Space' + 'd' + 's' to start a debugging session

-- Toggle breakpoint
map("n", "<leader>db", "<cmd>lua require'dap'.toggle_breakpoint()<CR>", { desc = "Nvim-Dap Toggle breakpoint" })
-- In normal mode, press 'Space' + 'd' + 'b' to toggle a breakpoint

-- Step over
map("n", "<leader>dn", "<cmd>lua require'dap'.step_over()<CR>", { desc = "Nvim-Dap Step over" })
-- In normal mode, press 'Space' + 'd' + 'n' to step over

-- Step into
map("n", "<leader>di", "<cmd>lua require'dap'.step_into()<CR>", { desc = "Nvim-Dap Step into" })
-- In normal mode, press 'Space' + 'd' + 'i' to step into

-- Nvim-Dap Step out
map("n", "<leader>do", "<cmd>lua require'dap'.step_out()<CR>", { desc = "Nvim-Dap Step out" })
-- In normal mode, press 'Space' + 'd' + 'o' to step out

-- Toggle DAP REPL
map("n", "<leader>dr", "<cmd>lua require'dap'.repl.toggle()<CR>", { desc = "Nvim-Dap Toggle DAP REPL" })
-- In normal mode, press 'Space' + 'd' + 'r' to toggle the DAP REPL

-- Show DAP UI
map("n", "<leader>du", "<cmd>lua require'dapui'.toggle()<CR>", { desc = "Nvim-Dap-UI toggle DAP UI" })
-- In normal mode, press 'Space' + 'd' + 'u' to toggle the DAP UI

return diagmap
