-- /qompassai/Diver/lsp/ccls.lua
-- Qompass AI C/C++/ObjC (CC) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
--[[
References:
https://github.com/MaskRay/ccls/wiki |
 https://clang.llvm.org/docs/JSONCompilationDatabase.html |
 https://cmake.org/cmake/help/latest/variable/CMAKE_EXPORT_COMPILE_COMMANDS.html |
 https://github.com/rizsotto/Bear |
 https://github.com/MaskRay/ccls/wiki/Customization#initialization-options
--]]
vim.lsp.config['cc_ls'] = {
  cmd = {
    'ccls',
  },
  filetypes = {
    'c',
    'cpp',
    'objc',
    'objcpp',
    'cuda',
  },
  offset_encoding = 'utf-8',
}