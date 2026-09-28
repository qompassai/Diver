-- Native snippets using vim.snippet (Neovim 0.10+).
-- Replaces LuaSnip + friendly-snippets (no plugins needed).

local M = {}

-- Common snippets by filetype.
-- Format: trigger -> snippet body ($1, $2, $0 for tab stops)
M.snippets = {
    lua = {
        ["func"] = "function ${1:name}(${2:args})\n\t$0\nend",
        ["if"] = "if $1 then\n\t$0\nend",
        ["for"] = "for ${1:i} = ${2:1}, ${3:10} do\n\t$0\nend",
        ["req"] = "local ${1:mod} = require()$0",
    },
    python = {
        ["def"] = "def ${1:name}(${2:args}):\n\t$0",
        ["if"] = "if $1:\n\t$0",
        ["for"] = "for ${1:x} in ${2:items}:\n\t$0",
        ["class"] = "class ${1:Name}:\n\tdef __init__(self$2):\n\t\t$0",
    },
    javascript = {
        ["func"] = "function ${1:name}(${2:args}) {\n\t$0\n}",
        ["if"] = "if ($1) {\n\t$0\n}",
        ["for"] = "for (let ${1:i} = 0; $1 < ${2:n}; $1++) {\n\t$0\n}",
    },
}

---Expand snippet at cursor if trigger matches.
function M.expand_or_jump()
    if vim.snippet.active({ direction = 1 }) then
        vim.snippet.jump(1)
        return true
    end

    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local before = line:sub(1, col)
    local trigger = before:match("(%S+)$")

    if trigger then
        local ft = vim.bo.filetype
        local ft_snippets = M.snippets[ft] or {}
        local body = ft_snippets[trigger]
        if body then
            -- Delete trigger and expand
            local start_col = col - #trigger
            vim.api.nvim_buf_set_text(0, vim.api.nvim_win_get_cursor(0)[1] - 1, start_col, vim.api.nvim_win_get_cursor(0)[1] - 1, col, { "" })
            vim.snippet.expand(body)
            return true
        end
    end
    return false
end

---Jump to previous snippet placeholder.
function M.jump_back()
    if vim.snippet.active({ direction = -1 }) then
        vim.snippet.jump(-1)
        return true
    end
    return false
end

---Setup keymaps for snippet expansion.
function M.setup()
    vim.keymap.set({ "i", "s" }, "<Tab>", function()
        if not M.expand_or_jump() then
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
        end
    end, { desc = "Expand snippet or jump forward" })

    vim.keymap.set({ "i", "s" }, "<S-Tab>", function()
        if not M.jump_back() then
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<S-Tab>", true, false, true), "n", false)
        end
    end, { desc = "Jump to previous snippet placeholder" })
end

return M
