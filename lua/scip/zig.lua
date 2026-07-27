-- ~/.config/nvim/lua/scip/zig.lua
local M = {}

local uv = vim.uv or vim.loop

local function is_dir(path)
  local stat = uv.fs_stat(path)
  return stat and stat.type == "directory"
end

local function is_file(path)
  local stat = uv.fs_stat(path)
  return stat and stat.type == "file"
end

local function join(...)
  return table.concat({ ... }, "/")
end

local function dirname(path)
  return vim.fs.dirname(path)
end

local function find_root(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end

  local start = dirname(name)
  local root_markers = {
    "build.zig",
    "build.zig.zon",
    ".git",
  }

  local found = vim.fs.find(root_markers, {
    upward = true,
    path = start,
    stop = vim.env.HOME,
  })[1]

  return found and dirname(found) or nil
end

local function find_scip_dir(root)
  if not root then
    return nil
  end

  local candidates = {
    join(root, ".scip"),
    join(root, "scip"),
    join(root, ".cache", "scip"),
    join(root, ".cache", "scip", "zig"),
  }

  for _, path in ipairs(candidates) do
    if is_dir(path) then
      return path
    end
  end

  return nil
end

local function find_scip_index(root)
  local dir = find_scip_dir(root)
  if not dir then
    return nil
  end

  local candidates = {
    join(dir, "index.scip"),
    join(dir, "zig.scip"),
    join(dir, "dump.scip"),
  }

  for _, path in ipairs(candidates) do
    if is_file(path) then
      return path
    end
  end

  return nil
end

local function scip_cmd(root)
  local index = find_scip_index(root)
  if not index then
    return nil
  end

  -- Adjust flags to your local scip-lsp if needed.
  return {
    "scip-lsp",
    "--index",
    index,
  }
end

function M.enable()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "zig", "ziggy", "zine", "zon" },
    callback = function(args)
      local bufnr = args.buf
      local root = find_root(bufnr)
      local cmd = scip_cmd(root)
      if not root or not cmd then
        return
      end

      vim.lsp.start({
        name = "scip_zig",
        cmd = cmd,
        root_dir = root,
        capabilities = vim.lsp.protocol.make_client_capabilities(),
      }, {
        bufnr = bufnr,
      })
    end,
  })
end

return M
