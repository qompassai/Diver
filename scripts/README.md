# venn-plus.nvim

A native Neovim 0.12+ plugin for drawing ASCII and UTF-8 box diagrams directly in buffers.

## Features

- Native Lua plugin layout for Neovim 0.12+
- Interactive line drawing with normal/visual mode keymaps
- UTF-8 box drawing or ASCII fallback
- Arrow placement helpers
- `:VennPlusBox` command for quick rectangles
- LuaCATS annotations for LuaLS

## Structure

```text
venn-plus.nvim/
├── lua/venn_plus/init.lua
├── plugin/venn_plus.lua
├── doc/venn-plus.txt
└── README.md
```

## Install

### Native package

Copy the directory into a runtime path location, such as:

```text
~/.config/nvim/pack/plugins/start/venn-plus.nvim
```

Neovim automatically loads Lua/Vim files placed under `plugin/` on startup, and the main implementation lives under `lua/`, which is the standard Lua plugin structure.[cite:187][cite:188]

### Example setup

The plugin auto-calls `setup()` from `plugin/venn_plus.lua`, so it works out of the box. To override defaults, call `setup()` yourself earlier in your config:

```lua
require("venn_plus").setup({
  prefer_utf8 = true,
  keymaps = {
    toggle = "<leader>V",
  },
})
```

## Commands

- `:VennPlusToggle`
- `:VennPlusEnable`
- `:VennPlusDisable`
- `:VennPlusBox [width] [height]`

## Default keymaps

When enabled:

- `H` draw left
- `J` draw down
- `K` draw up
- `L` draw right
- `f` right arrow
- `F` left arrow
- `g` up arrow
- `G` down arrow
- `<leader>v` toggle mode

## Notes

This plugin uses `vim.keymap.set()` and `vim.api.nvim_create_user_command()`, which are standard Neovim Lua APIs for mappings and commands.[cite:191][cite:154]
