-- #################################################################
-- /qompassai/Diver/lua/refactor/debug.lua
-- Native print-debug insertion and cleanup for Neovim 0.13+
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

local api = vim.api
local ts = vim.treesitter

local core = require('refactor.core')

local M = {}

local IDENTIFIER_COUNT_MAX = 64
local TREE_NODE_COUNT_MAX = 4096

---@class refactor.DebugGenerator
---@field location fun(label: string): string
---@field value fun(label: string, expression: string): string|nil, string?

---@class refactor.DebugConfig
---@field output_location "above"|"below"
---@field start_marker string
---@field end_marker string
---@field block_count_max integer
---@field cleanup_line_max integer
---@field generators table<string, refactor.DebugGenerator>

---@class refactor.DebugOpts
---@field bufnr? integer
---@field range? vim.Range
---@field visual? boolean
---@field output_location? "above"|"below"

local function quote_double(text)
    return '"' .. text:gsub('\\', '\\\\'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t'):gsub('"', '\\"') .. '"'
end

local function quote_single(text)
    return "'" .. text:gsub('\\', '\\\\'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t'):gsub("'", "\\'") .. "'"
end

local function js_generator()
    return {
        location = function(label)
            return ('console.log(%s);'):format(quote_double(label))
        end,
        value = function(label, expression)
            return ('console.log(%s, %s);'):format(quote_double(label), expression)
        end,
    }
end

local generators = {
    lua = {
        location = function(label)
            return ('print(%s)'):format(quote_double(label))
        end,
        value = function(label, expression)
            return ('print(%s, tostring(%s))'):format(quote_double(label), expression)
        end,
    },
    javascript = js_generator(),
    typescript = js_generator(),
    tsx = js_generator(),
    javascriptreact = js_generator(),
    python = {
        location = function(label)
            return ('print(%s)'):format(quote_single(label))
        end,
        value = function(label, expression)
            return ('print(%s, repr(%s))'):format(quote_single(label), expression)
        end,
    },
    ruby = {
        location = function(label)
            return ('warn(%s)'):format(quote_double(label))
        end,
        value = function(label, expression)
            return ('warn(%s + " " + (%s).inspect)'):format(quote_double(label), expression)
        end,
    },
    go = {
        location = function(label)
            return ('fmt.Println(%s)'):format(quote_double(label))
        end,
        value = function(label, expression)
            return ('fmt.Printf("%%s %%#v\\n", %s, %s)'):format(quote_double(label), expression)
        end,
    },
    cpp = {
        location = function(label)
            return ("std::cerr << %s << '\\n';"):format(quote_double(label))
        end,
        value = function(label, expression)
            return ('std::cerr << %s << " " << (%s) << \'\\n\';'):format(quote_double(label), expression)
        end,
    },
    c = {
        location = function(label)
            return ('fprintf(stderr, "%%s\\n", %s);'):format(quote_double(label))
        end,
        value = function(_, _)
            return nil, 'generic C value printing is type-unsafe; configure a type-aware C generator'
        end,
    },
    c_sharp = {
        location = function(label)
            return ('Console.Error.WriteLine(%s);'):format(quote_double(label))
        end,
        value = function(label, expression)
            return ('Console.Error.WriteLine("{0} {1}", %s, %s);'):format(quote_double(label), expression)
        end,
    },
    java = {
        location = function(label)
            return ('System.err.println(%s);'):format(quote_double(label))
        end,
        value = function(label, expression)
            return ('System.err.println(%s + " " + String.valueOf(%s));'):format(quote_double(label), expression)
        end,
    },
    kotlin = {
        location = function(label)
            return ('System.err.println(%s)'):format(quote_double(label))
        end,
        value = function(label, expression)
            return ('System.err.println(%s + " " + (%s).toString())'):format(quote_double(label), expression)
        end,
    },
    rust = {
        location = function(label)
            return ('eprintln!("{}", %s);'):format(quote_double(label))
        end,
        value = function(label, expression)
            return ('eprintln!("{} {:?}", %s, &(%s));'):format(quote_double(label), expression)
        end,
    },
    php = {
        location = function(label)
            return ('fwrite(STDERR, %s . PHP_EOL);'):format(quote_single(label))
        end,
        value = function(label, expression)
            return ('fwrite(STDERR, %s . " " . var_export(%s, true) . PHP_EOL);'):format(
                quote_single(label),
                expression
            )
        end,
    },
    powershell = {
        location = function(label)
            return ('Write-Host %s'):format(quote_single(label))
        end,
        value = function(label, expression)
            return ("Write-Host (%s + ' ' + ((%s) | Out-String))"):format(quote_single(label), expression)
        end,
    },
    vim = {
        location = function(label)
            return ('echom %s'):format(quote_single(label))
        end,
        value = function(label, expression)
            return ("echom %s . ' ' . string(%s)"):format(quote_single(label), expression)
        end,
    },
    mojo = {
        location = function(label)
            return ('print(%s)'):format(quote_double(label))
        end,
        value = function(label, expression)
            return ('print(%s, %s)'):format(quote_double(label), expression)
        end,
    },
}

local config = {
    output_location = 'below',
    start_marker = '__NATIVE_REFACTOR_DEBUG_START__',
    end_marker = '__NATIVE_REFACTOR_DEBUG_END__',
    block_count_max = 1024,
    cleanup_line_max = 250000,
    generators = generators,
}

---@param opts? refactor.DebugConfig
---@return nil
function M.setup(opts)
    if not opts then
        return
    end

    config = vim.tbl_deep_extend('force', config, opts)
end

---@param bufnr integer
---@param opts? refactor.DebugOpts
---@return vim.Range
local function target_range(bufnr, opts)
    if opts and opts.range then
        return opts.range
    end

    if opts and opts.visual then
        local selected = core.visual_range(bufnr)
        if selected then
            return selected
        end
    end

    return core.cursor_range(bufnr)
end

---@param node TSNode?
---@return boolean
local function identifier_like(node)
    if not node or node:child_count() ~= 0 then
        return false
    end

    local kind = node:type():lower()

    return kind == 'identifier'
        or kind == 'variable_name'
        or kind == 'field_identifier'
        or kind == 'property_identifier'
        or kind:sub(-11) == '_identifier'
end

---@param bufnr integer
---@param range vim.Range
---@return string[]
local function identifiers_in_range(bufnr, range)
    local root = core.node_at_range(bufnr, range)
    if not root then
        return {}
    end

    local identifiers = {}
    local seen = {}
    local stack = { root }
    local visited = 0

    while #stack > 0 and visited < TREE_NODE_COUNT_MAX do
        local node = table.remove(stack)
        visited = visited + 1

        local srow, scol, erow, ecol = node:range()
        local node_range = vim.range(bufnr, srow, scol, erow, ecol)

        if range:has(node_range) then
            if identifier_like(node) then
                local text = ts.get_node_text(node, bufnr)

                if text ~= '' and text:match('^[%a_][%w_]*$') and not seen[text] then
                    seen[text] = true
                    table.insert(identifiers, text)

                    if #identifiers >= IDENTIFIER_COUNT_MAX then
                        break
                    end
                end
            else
                for child in node:iter_children() do
                    table.insert(stack, child)
                end
            end
        end
    end

    table.sort(identifiers)
    return identifiers
end

---@param bufnr integer
---@param range vim.Range
---@return string?
local function expression_at_range(bufnr, range)
    if not range:is_empty() then
        local selected = vim.trim(core.range_text(range))
        if selected ~= '' then
            return selected
        end
    end

    local node = core.node_at_range(bufnr, range)
    if not node then
        return nil
    end

    return vim.trim(ts.get_node_text(node, bufnr))
end

---@param bufnr integer
---@param statement vim.Range
---@param kind string
---@param body string[]
---@param output_location? "above"|"below"
---@return boolean
local function insert_block(bufnr, statement, kind, body, output_location)
    local commentstring = core.commentstring(bufnr, statement)
    if not commentstring then
        core.notify('cannot determine commentstring for debug marker', vim.log.levels.ERROR)
        return false
    end

    local srow, _, erow, ecol = statement:to_extmark()
    local indent = core.indent_at(bufnr, srow)
    local location = output_location or config.output_location

    local node = core.node_at_range(bufnr, statement)
    if node then
        local node_type = node:type()
        if
            node_type:find('return', 1, true)
            or node_type:find('throw', 1, true)
            or node_type:find('break', 1, true)
            or node_type:find('continue', 1, true)
        then
            location = 'above'
        end
    end

    local current_nonce = vim.b[bufnr].native_refactor_debug_nonce or 0
    assert(type(current_nonce) == 'number')
    local nonce = current_nonce + 1
    vim.b[bufnr].native_refactor_debug_nonce = nonce

    local start = ('%s:%s:%d'):format(config.start_marker, kind, nonce)
    local finish = ('%s:%s:%d'):format(config.end_marker, kind, nonce)

    local lines = {
        indent .. core.comment(commentstring, start),
    }

    for _, line in ipairs(body) do
        table.insert(lines, indent .. line)
    end

    table.insert(lines, indent .. core.comment(commentstring, finish))

    local after_row = erow + (ecol > 0 and 1 or 0)
    local insert_row = location == 'above' and srow or after_row
    core.insert_lines(bufnr, insert_row, lines)
    return true
end

---@param bufnr integer
---@param range vim.Range
---@return refactor.DebugGenerator?
local function generator_for(bufnr, range)
    local lang = core.language(bufnr, range)
    local generator = config.generators[lang]

    if not generator then
        core.notify(('no debug generator configured for Tree-sitter language %q'):format(lang), vim.log.levels.WARN)
        return nil
    end

    return generator
end

---@param kind "print_loc"|"print_exp"|"print_var"
---@param opts? refactor.DebugOpts
---@return nil
local function run(kind, opts)
    opts = opts or {}

    local bufnr = core.bufnr(opts.bufnr)
    local range = target_range(bufnr, opts)
    local statement = core.statement_range(bufnr, range)
    local generator = generator_for(bufnr, statement)

    if not generator then
        return
    end

    local path = core.debug_path(bufnr, statement)
    local row = statement.start_row + 1
    local body = {}

    if kind == 'print_loc' then
        local label = ('[%s:%d]'):format(path, row)
        body[1] = generator.location(label)
    elseif kind == 'print_exp' then
        local expression = expression_at_range(bufnr, range)
        if not expression or expression == '' then
            core.notify('no expression found', vim.log.levels.WARN)
            return
        end

        local label = ('[%s:%d] %s ='):format(path, row, expression)
        local line, err = generator.value(label, expression)
        if not line then
            core.notify(err or 'debug value generation failed', vim.log.levels.ERROR)
            return
        end

        body[1] = line
    else
        local identifiers = identifiers_in_range(bufnr, range)

        if #identifiers == 0 then
            local expression = expression_at_range(bufnr, range)
            if expression and expression:match('^[%a_][%w_]*$') then
                identifiers[1] = expression
            end
        end

        if #identifiers == 0 then
            core.notify('no variable identifiers found', vim.log.levels.WARN)
            return
        end

        for _, identifier in ipairs(identifiers) do
            local label = ('[%s:%d] %s ='):format(path, row, identifier)
            local line, err = generator.value(label, identifier)
            if not line then
                core.notify(err or 'debug value generation failed', vim.log.levels.ERROR)
                return
            end
            table.insert(body, line)
        end
    end

    if insert_block(bufnr, statement, kind, body, opts.output_location) then
        core.notify(('%s inserted'):format(kind))
    end
end

---@param opts? refactor.DebugOpts
function M.print_loc(opts)
    run('print_loc', opts)
end

---@param opts? refactor.DebugOpts
function M.print_exp(opts)
    run('print_exp', opts)
end

---@param opts? refactor.DebugOpts
function M.print_var(opts)
    run('print_var', opts)
end

---@class refactor.CleanupOpts
---@field bufnr? integer
---@field range? vim.Range

---@param opts? refactor.CleanupOpts
---@return nil
function M.cleanup(opts)
    opts = opts or {}

    local bufnr = core.bufnr(opts.bufnr)
    local line_count = api.nvim_buf_line_count(bufnr)

    if line_count > config.cleanup_line_max then
        core.notify(
            ('cleanup refused: %d lines exceeds configured maximum %d'):format(line_count, config.cleanup_line_max),
            vim.log.levels.ERROR
        )
        return
    end

    local first_row = 0
    local last_row = line_count - 1

    if opts.range then
        first_row = opts.range.start_row
        last_row = opts.range.end_row
    end

    local lines = api.nvim_buf_get_lines(bufnr, first_row, math.min(last_row + 1, line_count), true)

    local blocks = {}
    local open_row = nil

    for index, line in ipairs(lines) do
        local row = first_row + index - 1

        if line:find(config.start_marker, 1, true) then
            if open_row ~= nil then
                core.notify(('nested debug marker at line %d; cleanup aborted'):format(row + 1), vim.log.levels.ERROR)
                return
            end
            open_row = row
        elseif line:find(config.end_marker, 1, true) then
            if open_row == nil then
                core.notify(
                    ('orphan debug end marker at line %d; cleanup aborted'):format(row + 1),
                    vim.log.levels.ERROR
                )
                return
            end

            table.insert(blocks, { open_row, row + 1 })
            open_row = nil

            if #blocks > config.block_count_max then
                core.notify(('cleanup exceeded %d debug blocks'):format(config.block_count_max), vim.log.levels.ERROR)
                return
            end
        end
    end

    if open_row ~= nil then
        core.notify('unterminated debug marker; cleanup aborted', vim.log.levels.ERROR)
        return
    end

    for index = #blocks, 1, -1 do
        local block = blocks[index]
        api.nvim_buf_set_lines(bufnr, block[1], block[2], true, {})
    end

    core.notify(('removed %d debug block(s)'):format(#blocks))
end

return M
