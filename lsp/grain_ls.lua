-- /qompassai/Diver/lsp/grain_ls.lua
-- Qompass AI Diver Grain LSP Spec
--curl -L \
--  --output "$HOME/.local/bin/grain" \
--  https://github.com/grain-lang/grain/releases/download/grain-v0.7.1/grain-linux-x64

--chmod +x "$HOME/.local/bin/grain"
---@type vim.lsp.Config
return {
    cmd = {
        'grain',
        'lsp',
        '--source-map',
        '--strict-sequence',
    },
    filetypes = {
        'grain',
    },
    root_markers = {
        'grain.toml',
        '.git',
    },
}
