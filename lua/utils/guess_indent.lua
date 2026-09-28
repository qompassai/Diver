-- Native guess-indent: detect indentation style from buffer content.
-- Replaces guess-indent.nvim (no plugin needed).

local M = {}

---Guess indent settings from buffer lines.
---@param bufnr integer Buffer number
function M.guess(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, math.min(100, vim.api.nvim_buf_line_count(bufnr)), false)

    local tab_count = 0
    local space_counts = {}

    for _, line in ipairs(lines) do
        local indent = line:match("^(%s*)")
        if indent and #indent > 0 and line:match("%S") then
            if indent:find("\t") then
                tab_count = tab_count + 1
            else
                local width = #indent
                space_counts[width] = (space_counts[width] or 0) + 1
            end
        end
    end

    if tab_count > 0 then
        local space_total = 0
        for _, c in pairs(space_counts) do
            space_total = space_total + c
        end
        if tab_count >= space_total then
            vim.bo[bufnr].expandtab = false
            return
        end
    end

    -- Find most common space width, prefer divisors
    local best_width, best_count = 4, 0
    for width, count in pairs(space_counts) do
        if count > best_count and width <= 8 then
            best_width, best_count = width, count
        end
    end

    vim.bo[bufnr].expandtab = true
    vim.bo[bufnr].shiftwidth = best_width
    vim.bo[bufnr].tabstop = best_width
end

---Setup autocmd to guess indent on file open.
function M.setup()
    local group = vim.api.nvim_create_augroup("DiverGuessIndent", { clear = true })
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
        group = group,
        callback = function(args)
            -- Skip special buffers
            if vim.bo[args.buf].buftype ~= "" then
                return
            end
            vim.schedule(function()
                M.guess(args.buf)
            end)
        end,
    })
end

return M
