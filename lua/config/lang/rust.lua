-- ~/.config/nvim/lua/config/lang/rust.lua
local M = {}

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = true,
  severity_sort = true,
})

M.rust_editions = {
  ["2021"] = "2021",
  ["2024"] = "2024",
}

M.rust_toolchains = {
  stable = "stable",
  nightly = "nightly",
  beta = "beta",
}

M.default_edition = "2021"
M.default_toolchain = "stable"

function M.set_rust_edition(edition)
  if M.rust_editions[edition] then
    M.current_edition = edition
    vim.notify("Rust edition set to " .. edition, vim.log.levels.INFO)
    vim.cmd("LspRestart")
  else
    vim.notify("Invalid Rust edition: " .. tostring(edition), vim.log.levels.ERROR)
  end
end

function M.set_rust_toolchain(toolchain)
  if M.rust_toolchains[toolchain] then
    M.current_toolchain = toolchain
    vim.notify("Rust toolchain set to " .. toolchain, vim.log.levels.INFO)
    vim.cmd("LspRestart")
  else
    vim.notify("Invalid Rust toolchain: " .. tostring(toolchain), vim.log.levels.ERROR)
  end
end

function M.refresh_diagnostics()
  vim.cmd("write")
  vim.diagnostic.disable()
  vim.defer_fn(function()
    vim.diagnostic.enable()
  end, 200)
end

function M.auto_detect_toolchain()
  local toolchain_file = vim.fn.findfile("rust-toolchain.toml", ".;")
  if toolchain_file ~= "" then
    local content = vim.fn.readfile(toolchain_file)
    for _, line in ipairs(content) do
      local edition = line:match("edition%s*=%s*\"(%d+)\"")
      local toolchain = line:match("channel%s*=%s*\"([%w%-]+)\"")
      if edition and M.rust_editions[edition] then
        M.set_rust_edition(edition)
      end
      if toolchain and M.rust_toolchains[toolchain] then
        M.set_rust_toolchain(toolchain)
      end
    end
  end
end

function M.rust_dap()
  local dap = require("dap")
  local dapui = require("dapui")
  dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
      command = "/usr/bin/codelldb",
      args = { "--port", "${port}" },
    },
  }
  dap.configurations.rust = {
    {
      name = "Launch",
      type = "codelldb",
      request = "launch",
      program = function()
        return vim.fn.input("Path to executable: " .. vim.fn.getcwd() .. "/")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
    },
  }
  dap.listeners.after.event_exited.dapui_config = function()
    dapui.close()
  end
end

function M.rust_nls()
  local null_ls = require("null-ls")
  return {
    null_ls.builtins.formatting.dxfmt.with({
      ft = { "rust" },
      command = "dx",
      extra_args = { "fmt", "--file", "$FILENAME" },
    }),
    null_ls.builtins.diagnostics.ltrs.with({
      method = null_ls.methods.DIAGNOSTICS,
      ft = { "text", "markdown" },
      command = "ltrs",
      extra_args = { "check", "-m", "-r", "--text", "$TEXT" },
    }),
    null_ls.builtins.formatting.leptosfmt.with({
      method = null_ls.methods.FORMATTING,
      ft = { "rust" },
      command = "leptosfmt",
      extra_args = { "--quiet", "--stdin" },
    }),
  }
end

function M.rust_crates()
  local crates = require("crates")
  crates.setup({
    smart_insert = true,
    insert_closing_quote = true,
    autoload = true,
    autoupdate = true,
    autoupdate_throttle = 250,
    loading_indicator = true,
    date_format = "%Y-%m-%d",
    thousands_separator = ".",
    notification_title = "crates.nvim",
    popup = {
      autofocus = false,
      hide_on_select = false,
      border = "none",
      show_version_date = true,
    },
    lsp = {
      enabled = true,
      name = "crates.nvim",
      actions = true,
      completion = true,
    },
  })
  vim.api.nvim_create_autocmd("BufRead", {
    pattern = "Cargo.toml",
    callback = function()
      vim.defer_fn(crates.show, 300)
    end,
  })
end

function M.rust()
  M.auto_detect_toolchain()
  M.rust_crates()
  vim.api.nvim_create_user_command("RustEdition", function(opts)
    M.set_rust_edition(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return vim.tbl_keys(M.rust_editions)
    end,
  })
  vim.api.nvim_create_user_command("RustToolchain", function(opts)
    M.set_rust_toolchain(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return vim.tbl_keys(M.rust_toolchains)
    end,
  })
  vim.keymap.set("n", "<leader>rd", M.refresh_diagnostics, { desc = "Refresh Diagnostics" })
  vim.keymap.set("n", "<leader>re", function()
    vim.ui.select(vim.tbl_keys(M.rust_editions), { prompt = "Select Rust Edition" }, M.set_rust_edition)
  end, { desc = "Select Rust Edition" })
  vim.keymap.set("n", "<leader>rt", function()
    vim.ui.select(vim.tbl_keys(M.rust_toolchains), { prompt = "Select Rust Toolchain" }, M.set_rust_toolchain)
  end, { desc = "Select Rust Toolchain" })
end

return M

