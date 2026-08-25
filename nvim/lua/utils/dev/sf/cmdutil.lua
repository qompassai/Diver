-- lua/utils/sf/cmdutil.lua
local M = {}

function M.get_arg(opts)
  if opts and type(opts.args) == 'string' and opts.args ~= '' then
    return opts.args
  end
  return nil
end

function M.input_required(prompt, completion)
  local value = vim.fn.input(prompt, '', completion)
  if value == '' then
    return nil
  end
  return value
end

function M.input_or_arg(opts, prompt, completion)
  return M.get_arg(opts) or M.input_required(prompt, completion)
end

return M
