-- /qompassai/Diver/lua/utils/lang/rust.lua
-- Qompass AI Rust Lang Utils
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local U = {}
local M = {}
M.rust_editions = {
  ['2021'] = '2021',
  ['2024'] = '2024',
}
M.rust_toolchains = {
  stable = 'stable',
  nightly = 'nightly',
  beta = 'beta',
}
M.rust_default_edition = '2024'
M.rust_default_toolchain = 'nightly'

function U.rust_edition(edition)
  if U.rust_editions[edition] then
    U.current_edition = edition
    vim.echo('Rust edition set to ' .. edition, vim.log.levels.INFO)
    vim.cmd('LspRestart')
  else
    vim.echo('Invalid Rust edition: ' .. tostring(edition), vim.log.levels.ERROR)
  end
end

function M.rust_set_toolchain(tc)
  if U.rust_toolchains[tc] then
    U.current_toolchain = tc
    vim.echo('Rust toolchain set to ' .. tc, vim.log.levels.INFO)
    vim.cmd('LspRestart')
  else
    vim.echo('Invalid Rust toolchain: ' .. tostring(tc), vim.log.levels.ERROR)
  end
end

function M.rust_auto_toolchain()
  local f = vim.fn.findfile('rust-toolchain.toml', '.;')
  if f ~= '' then
    for _, line in ipairs(vim.fn.readfile('f')) do
      local ed = line:match('edition%s*=%s*"(%d+)"')
      local tch = line:match('channel%s*=%s*"([%w%-]+)"')
      if ed then
        U.rust_edition(ed)
      end
      if tch then
        U.rust_set_toolchain(tch)
      end
    end
  end
end

return M