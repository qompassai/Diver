-- qompassai/Diver/.luacheckrc
-- Qompass AI Diver Luacheck Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
  std = 'max',
  globals = {
    'vim',
    'use',
    'describe',
    'it',
    'before_each',
    'after_each',
    'assert',
    'spy',
    'mock',
    'require',
    'package',
    'jit',
    'arg',
    'm'
  },
  unused_args = true,
  files = {
    ['spec/**/*.lua'] = {
      globals = {
        'describe',
        'it',
        'before_each',
        'after_each',
        'assert'
      }
    }
  },
  ignore = {
    '542',
    '211',
    '431',
    '113'
  },
  redefined = true,
  max_line_length = 150
}