-- ~/.config/nvim/after/ftplugin/lua.lua
-- -------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved

local cmp = require("cmp")
cmp.setup.buffer({
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "lazydev" },
    { name = "path" },
    { name = "buffer" },
  }),
})
