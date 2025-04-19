-----------------------|  Ansible |-------------------------------

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  pattern = {
    "*/playbooks/*.yml",
    "*/tasks/*.yml",
    "*/roles/*.yml",
    "*/handlers/*.yml",
    "*/ansible/*.yml",
  },
  callback = function()
    vim.bo.filetype = "ansible"
  end,
})
-----------------------|  Ansible |-------------------------------

-----------------------|   Lua    |-------------------------------
 vim.api.nvim_create_autocmd("FileType", {
    pattern = "lua",
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
      vim.opt_local.softtabstop = 2
      vim.opt_local.expandtab = true
    end
  })
-----------------------|   Lua    |-------------------------------
-----------------------| Teaching |-------------------------------

vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.diagnostic.open_float(nil, { focusable = false })
  end,
})
-----------------------| Teaching | --------------------------
-----------------------| Rust | ------------------------------
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.rs",
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  callback = function()
    require("mappings.rustmap").setup()
  end,
})

local cargo_cmds = {
  { "CargoTest", "test", "Run cargo tests" },
  { "CargoDoc", "doc --open", "Generate and open documentation" },
  { "CargoBuildAndroid", "build --target aarch64-linux-android", "Build for Android" },
  { "CargoBuildIos", "build --target aarch64-apple-ios", "Build for iOS" },
  { "CargoBuildWasm", "build --target wasm32-unknown-unknown", "Build for WASM" },
}

for _, cmd in ipairs(cargo_cmds) do
  vim.api.nvim_create_user_command(cmd[1], function()
    vim.cmd("!cargo " .. cmd[2])
  end, { desc = cmd[3] })
end

vim.api.nvim_create_user_command("CargoExpand", function()
  vim.cmd("!cargo expand")
end, { desc = "Expand macros in Rust source" })

vim.api.nvim_create_user_command("CargoNextest", function()
  vim.cmd("!cargo nextest run")
end, { desc = "Run tests with cargo-nextest" })

vim.api.nvim_create_user_command("CargoZigBuild", function()
  vim.cmd("!cargo zigbuild --target aarch64-unknown-linux-gnu")
end, { desc = "Zig cross compile for aarch64-linux-gnu" })

vim.api.nvim_create_user_command("CargoAudit", function()
  vim.cmd("!cargo audit")
end, { desc = "Audit Cargo.lock for vulnerabilities" })

vim.api.nvim_create_user_command("CargoWatch", function()
  vim.cmd("!cargo watch -x run")
end, { desc = "Watch and run app on file changes" })

vim.api.nvim_create_user_command("CargoBloat", function()
  vim.cmd("!cargo bloat --crates")
end, { desc = "Show crate-level binary bloat" })

vim.api.nvim_create_user_command("CargoCoverageOpen", function()
  vim.cmd("!xdg-open tarpaulin-report.html")
end, { desc = "Open last tarpaulin coverage report" })

vim.api.nvim_create_user_command("CargoFlamegraph", function()
  vim.cmd("!cargo flamegraph")
end, { desc = "Generate flamegraph for current project" })

vim.api.nvim_create_user_command("LeptosBuild", function()
  vim.cmd("!cargo leptos build --release")
end, { desc = "Build Leptos frontend" })

--pingora
vim.api.nvim_create_user_command("PingoraRun", function()
  vim.cmd("!sudo cargo run")
end, { desc = "Run Pingora with elevated privileges" })

-- trunk serve (for web UIs)
vim.api.nvim_create_user_command("TrunkServe", function()
  vim.cmd("!trunk serve")
end, { desc = "Serve via trunk (WASM/web)" })

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "Dockerfile.*", "*.Dockerfile", "Containerfile", "*.containerfile" },
  callback = function()
    vim.bo.filetype = "dockerfile"
  end,
})

--Discord
vim.filetype.add({
  pattern = {
    [".*/waybar/config"] = "jsonc",
    [".*/hypr/.*%.conf"] = "hyprlang",
  },
})

--vim.keymap.set("n", "<leader>cf", function()
--  require("conform").format({
--   lsp_format = "fallback",
--    async = true,
--    timeout_ms = 500,
--  })
--end, { desc = "Format buffer" })

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.nginx", "nginx.conf", "/etc/nginx/**/*.conf" },
  callback = function()
    vim.bo.filetype = "nginx"
  end,
})

------------------------ | Python |-------------------------------
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.autoindent = true
    vim.opt_local.smartindent = true
  end
})

local pytest_cmd = "pytest"
   vim.api.nvim_create_autocmd("FileType", {
    pattern = "python",
    callback = function()
      vim.api.nvim_buf_create_user_command(0, "PythonLint", function()
        vim.lsp.buf.format()
        vim.cmd("write")
        vim.notify("Python code linted and formatted", vim.log.levels.INFO)
      end, {})
    end
  })

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "python",
    callback = function()
      local function run_pytest_file()
        local file = vim.fn.expand("%:p")
        vim.cmd("split | terminal " .. pytest_cmd .. " " .. file)
      end

      local function run_pytest_function()
        local file = vim.fn.expand("%:p")
        local cmd = pytest_cmd .. " " .. file .. "::" .. vim.fn.expand("<cword>") .. " -v"
        vim.cmd("split | terminal " .. cmd)
      end

      vim.api.nvim_buf_create_user_command(0, "PyTestFile", run_pytest_file, {})
      vim.api.nvim_buf_create_user_command(0, "PyTestFunc", run_pytest_function, {})
    end
  })

-------------------------| Python |--------------------------------
-- Scala

vim.api.nvim_create_autocmd({ "CursorHold" }, {
  callback = function()
    vim.diagnostic.open_float(nil, {
      focusable = false,
      close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
      scope = "cursor",
    })
  end,
})

--MasonTools begin
vim.api.nvim_create_autocmd("User", {
  pattern = "MasonToolsStartingInstall",
  callback = function()
    vim.schedule(function()
      print("mason-tool-installer is starting")
    end)
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "MasonToolsUpdateCompleted",
  callback = function(e)
    vim.schedule(function()
      print(vim.inspect(e.data))
    end)
  end,
})
--MasonTools End
