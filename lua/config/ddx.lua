-- ~/.config/nvim/lua/config/ddx.lua
local M = {}

function M.register_null_ls()
  local null_ls_ok, null_ls = pcall(require, "null-ls")
  if not null_ls_ok then
    vim.notify("[ddx] null-ls not found", vim.log.levels.ERROR)
    return
  end

  null_ls.setup({})

  local registered = {}

  for _, category in ipairs({ "code_actions", "diagnostics", "formatting", "hover", "completion" }) do
    for name, builtin in pairs(null_ls.builtins[category]) do
      if not registered[name] then
        local ok = pcall(function()
          null_ls.register(builtin)
        end)
        if ok then
          registered[name] = true
        else
          vim.notify("[ddx] Failed to register null-ls builtin: " .. name, vim.log.levels.WARN)
        end
      end
    end
  end
end

return M
