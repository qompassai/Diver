# 11 · Neovim 0.13 Native

## Concept

The biggest recent shift in Neovim (across 0.11 → 0.13) is that features that
used to *require* community plugins are now **built in**. `diver`'s design goal
— "rely on no plugins if possible, make everything native" — is only achievable
because of these changes. This chapter maps each native feature to the Lua you
write to use it, and to where `diver` already does.

### 1. Native plugin management — `vim.pack`

Older configs needed `packer`, `lazy.nvim`, etc. Neovim 0.13 ships
`vim.pack`:

```lua
vim.pack.add({
    { src = 'https://github.com/folke/which-key.nvim', version = 'main' },
    { src = 'https://github.com/Saghen/blink.cmp', version = vim.version.range('1.*') },
})
vim.pack.update()   -- update everything
```

Each entry is a plain Lua **table spec** (Chapter 03) with `src`, optional
`version`/`branch`, and `update`. No plugin manager to install first.

### 2. Native LSP configuration — the `lsp/` directory

Older configs needed `nvim-lspconfig` plus a `require('lspconfig').xxx.setup{}`
call for every server. Neovim 0.13 reads **`lsp/<name>.lua`** files directly. A
file like `lsp/clangd_ls.lua` just returns a config table:

```lua
-- lsp/foo.lua
return {
    cmd       = { 'foo-language-server' },
    filetypes = { 'foo' },
    root_markers = { '.git' },
}
```

…and you switch it on with one line:

```lua
vim.lsp.enable('foo')
```

Neovim merges every `lsp/<name>.lua` on the `runtimepath`, with
`after/lsp/<name>.lua` winning last. You define behaviour with `vim.lsp.config`
and activate with `vim.lsp.enable` — no plugin in the chain.

### 3. Native completion — `vim.lsp.completion.enable`

Older configs needed `nvim-cmp` + sources + `LuaSnip`. Neovim 0.13 has built-in
completion. You turn it on per-client inside an `LspAttach` autocommand:

```lua
vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
```

with these global options (set in `diver`'s `init.lua`):

```lua
vim.bo.autocomplete = true
vim.bo.completeopt = 'menu,menuone,noselect'
```

### 4. Native inline (ghost-text) completion

Neovim 0.13 adds `textDocument/inlineCompletion` support:

```lua
vim.lsp.inline_completion.enable(true, {
    bufnr = bufnr, client_id = client.id, autotrigger = true,
})
```

### 5. Built-in global LSP keymaps

Modern Neovim creates these *unconditionally* — you do not map them yourself:
`grn` rename, `gra` code action, `grr` references, `gri` implementation,
`grt` type definition, `gO` document symbols, and `<C-s>` signature help in
insert mode.

### 6. New native options used in `diver`

`'autocomplete'`, `'autowriteall'`, treesitter-based folding
(`foldexpr = 'v:lua.vim.treesitter.foldexpr()'`), and `'winborder'` are all
recent native options that `init.lua` sets directly.

## In Diver

**`vim.pack`** — `lua/plugins/init.lua`:

```lua
local add = vim.pack.add
local range = vim.version.range
local plugins = {
    { src = github('Saghen/blink.cmp'), update = true, version = range('1.*') },
    { src = github('folke/which-key.nvim'), update = true, version = 'main' },
    -- ...
}
```

and `lua/plugins/core/init.lua`:

```lua
vim.pack.add({ ---@type vim.pack.Spec[]
    ...
})
```

**Native LSP completion + inline completion** — `lua/config/core/lsp.lua`,
`M.on_attach`:

```lua
if client.server_capabilities.completionProvider then
    vim.lsp.completion.enable(true, client.id, bufnr, {
        autotrigger = true,
        convert = function(item)
            return { abbr = item.label:gsub('%b()', '') }
        end,
    })
end
if client.server_capabilities.inlineCompletionProvider then
    vim.lsp.inline_completion.enable(true, {
        bufnr = bufnr, client_id = client.id, autotrigger = true,
    })
end
```

That `convert` callback uses a Lua pattern (`%b()` = a balanced `(...)` pair) to
strip the parentheses from completion labels — Chapter 06 in the wild.

**The `lsp/` directory** — the repo's top-level `lsp/` folder holds hundreds of
`*_ls.lua` files, each returning a server config table. `init.lua` sets
`g.lsp_enable_on_demand = true` so they activate as needed.

**Native treesitter folding** — `init.lua`:

```lua
wo.foldexpr   = 'v:lua.vim.treesitter.foldexpr()'
wo.foldmethod = 'expr'
```

and the Lua-side fold helper in `lua/utils/docs/docs.lua`:

```lua
function M.foldexpr()
    ...
    return b[buf].ts_folds and tree.foldexpr() or '0'
end
```

**Native options** — `init.lua` sets `bo.autocomplete = true`,
`o.autowriteall = true`, `o.winborder = 'rounded'`, all without a plugin.

## What is *still* a plugin (and why)

`diver` is plugin-*minimal*, not plugin-*zero*. A handful remain because their
job has no native equivalent yet: `blink.cmp` (a richer completion UI),
`nvim-treesitter` (grammar installation/updates), `which-key.nvim`, `LuaSnip`.
The lesson: prefer native first, reach for a plugin only when the native API
genuinely cannot do the job — and even then, load it with the native
`vim.pack`.

## Reference

In the **`learn_vim_api`** module:

- `enable_completion(client, bufnr)` — the annotated `LspAttach` →
  `vim.lsp.completion.enable` flow, including the nested-field truthiness guard.
- `pack_specs(repos)` — builds the `vim.pack.Spec[]` list from `owner/name`
  shorthands, showing the spec table shape.

## Try it yourself

```vim
:checkhealth vim.lsp          " see Enabled Configurations from your lsp/ dir
:lua print(vim.inspect(vim.lsp.get_clients()))
:lua print(type(vim.pack), type(vim.lsp.completion.enable))
```

The final chapter ties everything together — **Chapter 12, Putting It
Together**.
