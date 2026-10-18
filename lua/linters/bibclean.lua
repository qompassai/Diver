-- /qompassai/Diver/linters/bibclean.lua
-- Qompass AI Diver Bibclean Linter Spec
---@module 'linters.bibclean'
return ---@type vim.lint.Config
{
    append_fname = true,
    args = {
        '-no-prettyprint',
        '-check-values',
        '-warnings',
        '-no-quiet',
        '-no-file-position',
        -- "-init-file", "bibclean.ini",
        -- "-max-width", "80",
        -- "-scribe",
    },
    cmd = 'bibclean',
    env = nil,
    ignore_exitcode = true,
    ---@type LintBufferParser
    ---@param output string
    ---@param bufnr integer
    ---@return vim.Diagnostic.Set[]
    parser = function(output, bufnr)
        local diagnostics = {}
        if output == '' then
            return diagnostics
        end
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        local filename = vim.fs.basename(bufname)
        for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
            local marker, path, lnum, msg = line:match('^(%?%?)%s+(.-)%s+(%d+):%s*(.+)$')
            if marker == '??' and path and lnum and msg then
                lnum = tonumber(lnum) - 1
                local col = 0
                if vim.fs.basename(path) == filename or path == bufname then
                    local severity = msg:match('^[Ee]rror') and vim.diagnostic.severity.ERROR
                        or vim.diagnostic.severity.WARN
                    table.insert(diagnostics, {
                        col = col,
                        end_col = col + 1,
                        end_lnum = lnum,
                        lnum = lnum,
                        message = msg,
                        severity = severity,
                        source = 'bibclean',
                    })
                end
            end
        end
        return diagnostics
    end,
    stdin = false,
    stream = 'stderr',
}
