-- /qompassai/Diver/lsp/twiggy_ls.lua
-- Qompass AI Twiggy LSP Spec
--Reference: https://github.com/moetelo/twiggy
--pnpm add -g twiggy-language-server
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'twiggy-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'twig',
    },
    root_markers = { ---@type string[]
        'composer.json',
        '.git',
    },
}
