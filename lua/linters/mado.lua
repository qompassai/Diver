-- /qompassai/Diver/linters/mado.lua
-- Qompass AI Diver Mado Linter Spec
---@module 'linters.mado'
---@type vim.lint.Config
return {
    append_fname = true,
    args = {
        'lint',
        '--format',
        'unix',
        -- '--config',
        -- 'mado.toml',
    },
    cmd = 'mado',
    ignore_exitcode = true,
    ---@param bufnr integer
    ---@return vim.lint.Diagnostic[]
    parser = function(output, bufnr) ---@param output string
        if output == '' then
            return {}
        end
        local diagnostics = {}
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        local bufbase = vim.fs.basename(bufname)
        for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
            local path, lnum, col, msg = line:match('^(.-):(%d+):(%d+):%s*(.+)$')
            if not path then
                path, lnum, msg = line:match('^(.-):(%d+):%s*(.+)$')
            end
            if path and lnum and msg then
                local itembase = vim.fs.basename(path)
                if itembase == bufbase or path == bufname then
                    lnum = tonumber(lnum) - 1
                    col = tonumber(col or 1) - 1
                    diagnostics[#diagnostics + 1] = {
                        col = col,
                        end_col = col + 1,
                        end_lnum = lnum,
                        lnum = lnum,
                        message = msg,
                        severity = vim.diagnostic.severity.WARN,
                        source = 'mado',
                    }
                end
            end
        end
        return diagnostics
    end,
    stdin = false,
    stream = 'stdout',
}
