-- git.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.filetype.add {
  pattern = {
    ["^.*/gitconfig.*$"] = "gitconfig",
    ["^.*/gitignore.*$"] = "gitignore",
    ["^.*/gitcommit.*$"] = "gitcommit",
  },
}