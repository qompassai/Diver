local M = {}
local has_lspconfig, lspconfig = pcall(require, "lspconfig")
function M.mojo_lsp(opts)
  opts = opts or {}
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  if ok_cmp then
    capabilities = cmp_nvim_lsp.default_capabilities()
  end
  if has_lspconfig and lspconfig.mojo then
    lspconfig.mojo.setup({
      cmd = { "mojo-lsp-server" },
      filetypes = { "mojo" },
      root_dir = lspconfig.util.root_pattern(".git"),
      single_file_support = true,
      settings = opts.settings or {},
      capabilities = opts.capabilities or capabilities,
      on_attach = opts.on_attach,
    })
  elseif vim.lsp and vim.lsp.config then
    vim.lsp.config({
      name = "mojo",
      cmd = { "mojo-lsp-server" },
      filetypes = { "mojo" },
      root_dir = vim.loop.cwd,
      settings = opts.settings or {},
    })
    vim.lsp.enable("mojo")
  else
    vim.notify("Mojo LSP not available in this Neovim version", vim.log.levels.WARN)
  end
end
function M.mojo_filetype()
  local ok, ft = pcall(require, "filetype")
  if ok then
    ft.add({
      extension = { mojo = "mojo" },
      pattern = { [".*%.🔥"] = "mojo" },
    })
  else
    vim.cmd([[
      augroup MojoFiletype
        autocmd BufNewFile,BufRead *.mojo set filetype=mojo
        autocmd BufNewFile,BufRead *.🔥 set filetype=mojo
      augroup END
    ]])
  end
end
function M.mojo_editor()
  pcall(vim.api.nvim_create_autocmd, "FileType", {
    pattern = { "mojo" },
    callback = function(args)
      if vim.bo[args.buf].filetype ~= "mojo" then
        return
      end
      vim.opt_local.tabstop = 4
      vim.opt_local.shiftwidth = 4
      vim.opt_local.expandtab = true
      pcall(vim.keymap.set, "n", "<leader>mr", ":MojoRun<CR>", {
        buffer = args.buf,
        desc = "Run Mojo file",
      })
      pcall(vim.keymap.set, "n", "<leader>md", ":MojoDebug<CR>", {
        buffer = args.buf,
        desc = "Debug Mojo file",
      })
    end,
  })
end
function M.mojo_attach_handlers(opts)
  opts = opts or {}
  local group = vim.api.nvim_create_augroup("MojoLspConfig", {})
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= "mojo" then
        return
      end
      local bufnr = args.buf
      if opts.keymaps ~= false then
        pcall(vim.keymap.set, "n", "gd", vim.lsp.buf.definition, {
          buffer = bufnr,
          desc = "Go to definition",
        })
        pcall(vim.keymap.set, "n", "K", vim.lsp.buf.hover, {
          buffer = bufnr,
          desc = "Hover documentation",
        })
      end
      if opts.format_on_save and client.supports_method("textDocument/formatting") then
        vim.api.nvim_create_autocmd("BufWritePre", {
          group = group,
          buffer = bufnr,
          callback = function()
            vim.lsp.buf.format({
              bufnr = bufnr,
              timeout_ms = 1000,
              filter = function(c)
                return c.name == "mojo"
              end,
            })
          end,
        })
      end
    end,
  })
end
function M.setup_mojo(opts)
  opts = vim.tbl_deep_extend("force", {
    format_on_save = true,
    enable_linting = true,
    dap_enabled = false,
    keymaps = true,
  }, opts or {})
  M.mojo_filetype()
  M.mojo_editor()
  if vim.fn.executable("mojo-lsp-server") == 1 then
    M.mojo_lsp(opts)
    M.mojo_attach_handlers(opts)
  end
  return M
end
return M
