-- /qompassai/Diver/lsp/tinymist.lua
-- Qompass AI Tinymist LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local function create_tinymist_command(command_name, client, bufnr)
  local export_type = command_name:match('tinymist%.export(%w+)')
  local info_type   = command_name:match('tinymist%.(%w+)')
  local raw_name    = export_type or info_type or command_name
  local cmd_display = raw_name
      :gsub('^get', 'Get')
      :gsub('^pin', 'Pin')
  local function cmd_func()
    vim.lsp.buf_request(bufnr, command_name, {}, function(err, result, ctx, _)
      if err then
        vim.notify(
          ('Tinymist command %s failed: %s'):format(command_name, err.message or tostring(err)),
          vim.log.levels.ERROR
        )
        return
      end
      vim.notify(
        ('Tinymist command %s finished'):format(command_name),
        vim.log.levels.INFO
      )
      if result ~= nil then
        print(vim.inspect(result))
      end
    end)
  end
  local cmd_name = cmd_display
  local cmd_desc = ('Tinymist: %s'):format(cmd_display)
  return cmd_func, cmd_name, cmd_desc
end
vim.lsp.config['tinymist_ls'] = {
  cmd = {
    'tinymist'
  },
  filetypes = {
    'typst'
  },
  root_markers = {
    '.git'
  },
  on_attach = function(client, bufnr)
    for _, command in ipairs {
      'tinymist.exportSvg',
      'tinymist.exportPng',
      'tinymist.exportPdf',
      -- 'tinymist.exportHtml', -- Use typst 0.13
      'tinymist.exportMarkdown',
      'tinymist.exportText',
      'tinymist.exportQuery',
      'tinymist.exportAnsiHighlight',
      'tinymist.getServerInfo',
      'tinymist.getDocumentTrace',
      'tinymist.getWorkspaceLabels',
      'tinymist.getDocumentMetrics',
      'tinymist.pinMain',
    } do
      local cmd_func, cmd_name, cmd_desc = create_tinymist_command(command, client, bufnr)
      vim.api.nvim_buf_create_user_command(
        bufnr,
        'Lsp' .. cmd_name,
        cmd_func,
        {
          nargs = 0,
          desc = cmd_desc
        }
      )
    end
  end,
}