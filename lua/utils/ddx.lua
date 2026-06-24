-- /qompassai/Diver/lua/utils/ddx.lua
-- Qompass AI Diver Util Differential Diagnosis (DDX) config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local api = vim.api
local fn = vim.fn
local notify = vim.notify
local uv = vim.uv
local levels = vim.log.levels
local function strip_ansi(bufnr)
  local cur = api.nvim_get_current_buf()
  if bufnr and api.nvim_buf_is_valid(bufnr) and bufnr ~= cur then
    api.nvim_set_current_buf(bufnr)
  end
  vim.cmd([[%s/\%x1b\[[0-9;]*m//g]])
  if bufnr and api.nvim_buf_is_valid(cur) and api.nvim_get_current_buf() ~= cur then
    api.nvim_set_current_buf(cur)
  end
end
local function scandir(root)
  local handle = uv.fs_scandir(root)
  if not handle then
    return {}
  end
  local results = {}
  while true do
    local name, t = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    results[#results + 1] = {
      name = name,
      type = t,
    }
  end
  return results
end
local function to_module(root, path)
  local rel = path:gsub("^" .. vim.pesc(root) .. "/?", "")
  rel = rel:gsub("%.lua$", "")
  rel = rel:gsub("/", ".")
  rel = rel:gsub("%.init$", "")
  return rel
end
local function collect_lua_files(root)
  local files = {}

  local function walk(dir)
    for _, entry in ipairs(scandir(dir)) do
      local full = dir .. "/" .. entry.name
      if entry.type == "file" and entry.name:match("%.lua$") then
        files[#files + 1] = full
      elseif entry.type == "directory" then
        walk(full)
      end
    end
  end

  walk(root)
  table.sort(files)
  return files
end

local function make_qf_item(file, text)
  return {
    filename = file,
    lnum = 1,
    col = 1,
    text = text,
  }
end
local function selfcheck()
  local lua_root = fn.stdpath("config") .. "/lua"
  local files = collect_lua_files(lua_root)
  local ok_count, err_count = 0, 0
  local qf_items = {}

  local state_dir = fn.stdpath("state")
  fn.mkdir(state_dir, "p")

  local log_path = state_dir .. "/selfcheck.log"
  local fh = io.open(log_path, "w")

  if fh then
    fh:write(("[selfcheck] %s\n"):format(os.date("%Y-%m-%d %H:%M:%S")))
    fh:write(("[selfcheck] lua_root=%s\n"):format(lua_root))
    fh:write(("[selfcheck] state_dir=%s\n"):format(state_dir))
    fh:write(("[selfcheck] log_path=%s\n\n"):format(log_path))
  end

  for _, file in ipairs(files) do
    local mod = to_module(lua_root, file)
    package.loaded[mod] = nil
    local ok, result = pcall(require, mod)

    if ok then
      ok_count = ok_count + 1
      if fh then
        fh:write(("[selfcheck] OK: %s | %s\n"):format(mod, file))
      end
    else
      err_count = err_count + 1
      local short_file = file:gsub("^" .. vim.pesc(lua_root) .. "/?", "")
      local err = tostring(result)
      local msg = table.concat({
        ("[selfcheck] %s FAILED:"):format(mod),
        ("  %s"):format(err),
        ("  File: %s"):format(short_file),
        ("  Full path: %s"):format(file),
      }, "\n")

      qf_items[#qf_items + 1] = make_qf_item(file, ("[%s] %s"):format(mod, err))

      notify(msg, levels.ERROR)
      if fh then
        fh:write(msg .. "\n")
        fh:write(string.rep("-", 80) .. "\n")
      end
    end
  end

  if #qf_items > 0 then
    fn.setqflist({}, "r", {
      title = "ConfigSelfCheck",
      items = qf_items,
    })
    vim.cmd("copen")
  else
    fn.setqflist({}, "r", {
      title = "ConfigSelfCheck",
      items = {},
    })
  end

  local summary = ("[selfcheck] %d OK, %d FAILED (log: %s)"):format(ok_count, err_count, log_path)
  notify(summary, err_count == 0 and levels.INFO or levels.ERROR)

  if fh then
    fh:write(("\n[selfcheck] %d OK, %d FAILED\n"):format(ok_count, err_count))
    fh:close()
  end
end

api.nvim_create_user_command("ConfigSelfCheck", selfcheck, {
  desc = "Require all lua config modules, write a log, and populate quickfix on failures",
})

api.nvim_create_user_command("ConfigSelfCheckLog", function()
  vim.cmd(("edit %s"):format(fn.fnameescape(fn.stdpath("state") .. "/selfcheck.log")))
end, {
  desc = "Open the ConfigSelfCheck log file",
})

api.nvim_create_autocmd("BufReadPost", {
  pattern = "*",
  callback = function(args)
    if vim.bo[args.buf].filetype == "nvimpager" then
      strip_ansi(args.buf)
    end
  end,
})

if vim.lsp and vim.lsp.log and vim.lsp.log.set_level then
  vim.lsp.set_log_level = function(...)
    return vim.lsp.log.set_level(...)
  end
end

return {
  run = selfcheck,
}