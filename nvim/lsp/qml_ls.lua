-- /qompassai/Diver/lsp/qml_ls.lua
-- Qompass AI Diver QML LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@source https://doc.qt.io/qt-6/qtqml-tooling-qmlls.html
local qs_imports = '/usr/share/quickshell'
local qt_docs = '/usr/share/doc/qt6'
if vim.fn.exists(':QmlFormat') == 0 then
  vim.api.nvim_create_user_command('QmlFormat', function()
    local file = vim.fn.expand('%:p')
    if file == '' or vim.fn.executable('qmlformat') ~= 1 then
      return
    end
    vim.fn.system({
      'qmlformat',
      '-i',
      file,
    })
    vim.cmd('checktime')
  end, {})
end
vim.api.nvim_create_autocmd('FileType', {
  pattern = {
    'qml',
    'qmljs',
  },
  callback = function(ev)
    if vim.b[ev.buf].qmlformat_on_save then
      return
    end
    vim.b[ev.buf].qmlformat_on_save = true
    vim.api.nvim_create_autocmd('BufWritePre', {
      buffer = ev.buf,
      callback = function()
        local file = vim.api.nvim_buf_get_name(ev.buf)
        if file == '' or vim.fn.executable('qmlformat') ~= 1 then
          return
        end
        vim.fn.system({
          'qmlformat',
          '-i',
          file,
        })
        vim.cmd('checktime')
      end,
    })
  end,
})
return {
  cmd = {
    'qmlls6',
    '--build-dir',
    vim.fn.getcwd() .. '/build',
    '-I',
    qs_imports,
    '-E',
    '--doc-dir',
    qt_docs,
    '--no-cmake-calls',
    '--cmake-jobs',
    'max',
    '--verbose',
    '--log-file',
    '/tmp/qmlls.log',
  },
  cmd_env = {
    QMLLS_BUILD_DIRS = vim.fn.getcwd() .. '/build',
    QML_IMPORT_PATH = qs_imports,
    QMLLS_NO_CMAKE_CALLS = '1',
    QMLLS_CMAKE_JOBS = 'max',
    QMLLS_MAX_FILES_TO_SEARCH = '20000',
  },
  filetypes = {
    'qml',
    'qmljs',
  },
  root_markers = {
    {
      'CMakeLists.txt',
      '.qmlls.ini',
      'qmldir',
    },
    '.git',
  },
  settings = {},
}
