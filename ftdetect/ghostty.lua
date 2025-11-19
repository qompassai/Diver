-- qompassai/Diver/ftdetect/ghostty.lua
-- Qompass AI Ghostty File Detection
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.filetype.add {
  pattern = {
    [".*/ghostty/config"] = "ghostty",
    ["ghostty%.conf"]     = "ghostty",
  },
}