-- ~/.config/nvim/lua/config/lang/mojo.lua
------------------------------------------
local M = {}
function M.mojo_lsp(opts)
  opts = opts or {}
  vim.lsp.config['mojo'] = {
    cmd = { "mojo-lsp-server" },
    filetypes = { "mojo" },
    root_markers = { ".git" },
    single_file_support = true,
    settings = opts.settings or {},
    capabilities = opts.capabilities,
  }
  vim.lsp.enable('mojo')
end
function M.mojo_filetype()
  vim.filetype.add({
    extension = {
      mojo = "mojo",
    },
    pattern = {
      [".*%.🔥"] = "mojo",
    },
  })
end
function M.mojo_editor()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "mojo" },
    callback = function()
      vim.opt_local.tabstop = 4
      vim.opt_local.shiftwidth = 4
      vim.opt_local.expandtab = true
      vim.keymap.set("n", "<leader>mr", ":MojoRun<CR>", { buffer = true, desc = "Run Mojo file" })
      vim.keymap.set("n", "<leader>md", ":MojoDebug<CR>", { buffer = true, desc = "Debug Mojo file" })
    end,
  })
end
function M.mojo_attach_handlers(opts)
  opts = opts or {}
  local group = vim.api.nvim_create_augroup('MojoLspConfig', {})
  vim.api.nvim_create_autocmd('LspAttach', {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= "mojo" then
        return
      end
      local bufnr = args.buf
      if opts.keymaps ~= false then
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr, desc = "Go to definition" })
        vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = bufnr, desc = "Hover documentation" })
        if opts.on_attach then
          opts.on_attach(client, bufnr)
        end
      end
      if opts.format_on_save and client.supports_method("textDocument/formatting") then
        vim.api.nvim_create_autocmd("BufWritePre", {
          group = group,
          buffer = bufnr,
          callback = function()
            vim.lsp.buf.format({ bufnr = bufnr, timeout_ms = 1000 })
          end,
        })
      end
    end,
  })
end
function M.setup_mojo(opts)
  opts = opts or {}
  M.mojo_filetype()
  M.mojo_lsp(opts)
  M.mojo_editor()
  M.mojo_attach_handlers(opts)
  return {
    format_on_save = opts.format_on_save or true,
    enable_linting = opts.enable_linting or true,
    dap = { enabled = opts.dap_enabled or true },
    keymaps = opts.keymaps or true,
  }
end
return M
