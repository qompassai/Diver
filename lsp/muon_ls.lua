-- /qompassai/Diver/lsp/muon.lua
-- Qompass AI Muon LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--- https://muon.build
-- git clone https://github.com/muon-build/muon.git && cd muon && ./bootstrap.sh build \
--&& build/muon-bootstrap setup build && build/muon-bootstrap -C build samu \
-- && build/muon-bootstrap -C build test && sudo build/muon-bootstrap -C build install
---@type vim.lsp.Config
return {
  cmd = {
    'muon',
    'analyze',
    'lsp',
  },
  filetypes = {
    'meson',
  },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local cmd = {
      'muon',
      'analyze',
      'root-for',
      fname,
    }
    vim.system(cmd, { text = true }, function(output)
      if output.code == 0 then
        if output.stdout then
          on_dir(vim.trim(output.stdout))
          return
        end
        on_dir(nil)
      else
        vim.notify(('[muon] cmd failed with code %d: %s\n%s'):format(output.code, cmd, output.stderr))
      end
    end)
  end,
}