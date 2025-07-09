local M = {}

local default_config = {
    priority = 10,

    hide_in_unfocused_buffer = true,

    link_highlights = true,

    validate_config = "auto",
    -- Example: { "quickfix", "refactor.rewrite" }
    -- See: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#codeActionKind
    action_kinds = nil,

    -- Enable code lens support.
    -- If the current position has executable code lenses, the icon is changed from `text` to `lens_text`
    -- for sign, virtual_text, float and status_text.
    -- The code lens icon is configurable per handler.
    code_lenses = true,

    -- Configuration for various handlers:
    -- 1. Sign column.
    sign = {
        enabled = true,
        text = "💡",
        lens_text = "🔎",
        hl = "LightBulbSign",
    },

    -- 2. Virtual text.
    virtual_text = {
        enabled = true,
        -- Text to show in the virt_text.
        text = "💡",
        lens_text = "🔎",
        -- Position of virtual text given to |nvim_buf_set_extmark|.
        -- Can be a number representing a fixed column (see `virt_text_pos`).
        -- Can be a string representing a position (see `virt_text_win_col`).
        pos = "eol",
        -- Highlight group to highlight the virtual text.
        hl = "LightBulbVirtualText",
        -- How to combine other highlights with text highlight.
        -- See `hl_mode` of |nvim_buf_set_extmark|.
        hl_mode = "combine",
    },

    -- 3. Floating window.
    float = {
        enabled = true,
        -- Text to show in the floating window.
        text = "💡",
        lens_text = "🔎",
        -- Highlight group to highlight the floating window.
        hl = "LightBulbFloatWin",
        -- Window options.
        -- See |vim.lsp.util.open_floating_preview| and |nvim_open_win|.
        -- Note that some options may be overridden by |open_floating_preview|.
        win_opts = {
            focusable = false,
        },
    },

    -- 4. Status text.
    -- When enabled, will allow using |NvimLightbulb.get_status_text|
    -- to retrieve the configured text.
    status_text = {
        enabled = true,
        -- Text to set if a lightbulb is available.
        text = "💡",
        lens_text = "🔎",
        -- Text to set if a lightbulb is unavailable.
        text_unavailable = "",
    },

    -- 5. Number column.
    number = {
        enabled = true,
        -- Highlight group to highlight the number column if there is a lightbulb.
        hl = "LightBulbNumber",
    },

    -- 6. Content line.
    line = {
        enabled = true,
        -- Highlight group to highlight the line if there is a lightbulb.
        hl = "LightBulbLine",
    },

    -- Autocmd configuration.
    -- If enabled, automatically defines an autocmd to show the lightbulb.
    -- If disabled, you will have to manually call |NvimLightbulb.update_lightbulb|.
    -- Only works if configured during NvimLightbulb.setup
    autocmd = {
        -- Whether or not to enable autocmd creation.
        enabled = true,
        -- See |updatetime|.
        -- Set to a negative value to avoid setting the updatetime.
        updatetime = 200,
        -- See |nvim_create_autocmd|.
        events = { "CursorHold", "CursorHoldI" },
        -- See |nvim_create_autocmd| and |autocmd-pattern|.
        pattern = { "*" },
    },

    -- Scenarios to not show a lightbulb.
    ignore = {
        -- LSP client names to ignore.
        -- Example: {"null-ls", "lua_ls"}
        clients = {},
        -- Filetypes to ignore.
        -- Example: {"neo-tree", "lua"}
        ft = {},
        -- Ignore code actions without a `kind` like refactor.rewrite, quickfix.
        actions_without_kind = false,
    },

    --- A general filter function for code actions.
    --- The function is called for code actions *after* any `ignore` or `action_kinds`
    --- options are applied.
    --- The function should return true to keep the code action, false otherwise.
    ---@type (fun(client_name:string, result:lsp.CodeAction|lsp.Command):boolean)|nil
    filter = nil,
}
return M
