-- /qompassai/Diver/lua/config/lang/shader.lua
-- Qompass AI Diver Shader Lang Config
---@module 'config.lang.shader'
-- Tooling (verified 2026-10-10): this module serves the wgsl and
-- glsl filetype families. Their language servers are wgsl-analyzer
-- (lsp/wgslana_ls.lua) and glsl_analyzer (lsp/glslana_ls.lua), both
-- enabled centrally. The formatters catalog formats wgsl with
-- wgslfmt; the linters catalog checks glsl with glslc and wgsl
-- with naga. The treesitter wgsl, wgsl_bevy, and glsl parsers are
-- installed. WGSL style follows the tiger-style-wgsl guide; GLSL
-- follows the C-family discipline. ShaderLab/HLSL are NOT claimed:
-- lsp/shader_ls.lua exists but is disabled in-tree as outdated.
-- No credible language-specific MCP server or package-publish flow
-- exists for shader sources, so none is declared here.
local M = {}
local api = vim.api
local fn = vim.fn
local group = api.nvim_create_augroup('Shader', {
    clear = true,
})
local header = require('research.docs')
local modernize = require('config.lang.modernize')

local function buf_is_empty()
    return api.nvim_buf_get_lines(0, 0, 1, false)[1] == ''
end

api.nvim_create_autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.comp',
        '*.frag',
        '*.geom',
        '*.glsl',
        '*.tesc',
        '*.tese',
        '*.vert',
        '*.wgsl',
    },
    callback = function()
        if not buf_is_empty() then
            return
        end
        local filepath = fn.expand('%:p')
        local hdr = header.make_header(filepath, '//')
        api.nvim_buf_set_lines(0, 0, 0, false, hdr)
        vim.cmd('normal! G')
    end,
})

local REPLACEMENTS = {}

---Modernize deprecated shader syntax in the current buffer. The
---replacement table is shared by the wgsl and glsl families, so the
---check runs against whichever shader filetype the buffer carries.
function M.modernize()
    local bufnr = api.nvim_get_current_buf()
    modernize.buffer(vim.bo[bufnr].filetype, REPLACEMENTS, 'shader')
end

return M
