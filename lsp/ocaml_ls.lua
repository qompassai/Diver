-- /qompassai/Diver/lsp/ocamllsp.lua
-- Qompass AI OCaml LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
--Reference: https://github.com/ocaml/ocaml-lsp
--opam install ocaml-lsp-server
local function switch_impl_intf(bufnr, client)
  local method_name = 'ocamllsp/switchImplIntf'
  ---@diagnostic disable-next-line:param-type-mismatch
  if not client or not client:supports_method(method_name) then
    return vim.echo(('method %s is not supported by any servers active on the current buffer'):format(method_name))
  end
  local uri = vim.lsp.util.make_given_range_params(
    nil, ---@type string
    nil,
    bufnr,
    client.offset_encoding
  ).textDocument.uri
  if not uri then
    return vim.echo('could not get URI for current buffer')
  end
  local params = { uri }
  ---@diagnostic disable-next-line:param-type-mismatch
  client:request(method_name, params, function(err, result)
    if err then
      error(tostring(err))
    end
    if not result or #result == 0 then
      vim.echo('corresponding file cannot be determined')
    elseif #result == 1 then
      vim.cmd.edit(vim.uri_to_fname(result[1]))
    else
      vim.ui.select(result, {
        prompt = 'Select an implementation/interface:',
        format_item = vim.uri_to_fname, ---@type fun(item: string): string
      }, function(choice)
        if choice then
          vim.cmd.edit(vim.uri_to_fname(choice))
        end
      end)
    end
  end, bufnr)
end
local language_id_of = {
  menhir = 'ocaml.menhir',
  ocaml = 'ocaml',
  ocamlinterface = 'ocaml.interface',
  ocamllex = 'ocaml.ocamllex',
  reason = 'reason',
  dune = 'dune',
}
local language_id_of_ext = {
  mll = language_id_of.ocamllex,
  mly = language_id_of.menhir,
  mli = language_id_of.ocamlinterface,
}
local get_language_id = function(bufnr, ftype)
  if ftype == 'ocaml' then
    local path = vim.api.nvim_buf_get_name(bufnr)
    local ext = vim.fn.fnamemodify(path, ':e')
    return language_id_of_ext[ext] or language_id_of.ocaml
  else
    return language_id_of[ftype]
  end
end
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'ocamllsp',
  },
  filetypes = { ---@type string[]
    'ocaml',
    'ocamlinterface',
    'ocamllex',
    'reason',
  },
  root_markers = { ---@type string[]
    'dune-project',
    'dune-workspace',
    '.git',
    '*.opam',
    'opam',
    'esy.json',
    'package.json',
  },
  get_language_id = get_language_id,
  on_attach = function(client, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr,
      'LspOcamllspSwitchImplIntf', function()
        switch_impl_intf(bufnr, client)
      end, {
        desc = 'Switch between implementation/interface',
      })
  end,
}