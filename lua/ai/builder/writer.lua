-- /qompassai/Diver/lua/ai/builder/writer.lua
-- Qompass AI Interactive Application Builder: Confirmed File Writer (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Writes generated files to disk only after the review stage is
-- confirmed. Creates directories with mkdir -p, refuses to overwrite an
-- existing file without a second explicit per-file confirmation, writes
-- atomically (temp file + rename), and reports created/skipped paths.
-- All paths are validated to stay inside the target directory.

local M = {}

---@class BuilderFile
---@field path string Relative path inside the target directory.
---@field content string Exact file bytes to write.

local FILE_COUNT_MAX = 256
local FILE_SIZE_BYTES_MAX = 1048576
local PATH_LEN_MAX = 512

---@param rel string
---@return string? clean
---@return string? err
local function sanitize_rel_path(rel)
    if type(rel) ~= 'string' or rel == '' then
        return nil, 'path must be a non-empty string'
    end
    if #rel > PATH_LEN_MAX then
        return nil, 'path exceeds length bound'
    end
    if rel:find('%z') ~= nil then
        return nil, 'path contains NUL'
    end
    if rel:sub(1, 1) == '/' then
        return nil, 'path must be relative, not absolute'
    end
    for segment in rel:gmatch('[^/]+') do
        if segment == '..' then
            return nil, 'path must not contain ..'
        end
    end
    return rel, nil
end

---Validate the shape of a generated file list without touching disk.
---@param files table Candidate file list.
---@return boolean? ok
---@return string? err
function M.validate_files(files)
    if type(files) ~= 'table' then
        return nil, 'files must be a table'
    end
    if #files == 0 then
        return nil, 'file list is empty'
    end
    if #files > FILE_COUNT_MAX then
        return nil, 'file count exceeds bound'
    end
    local seen = {}
    for index, file in ipairs(files) do
        if type(file) ~= 'table' then
            return nil, 'file #' .. index .. ' is not a table'
        end
        local rel, rel_err = sanitize_rel_path(file.path)
        if rel == nil then
            return nil, 'file #' .. index .. ': ' .. tostring(rel_err)
        end
        if type(file.content) ~= 'string' then
            return nil, 'file #' .. index .. ' content must be a string'
        end
        if #file.content > FILE_SIZE_BYTES_MAX then
            return nil, 'file #' .. index .. ' exceeds size bound'
        end
        if seen[rel] then
            return nil, 'duplicate path: ' .. rel
        end
        seen[rel] = true
    end
    return true, nil
end

---@param target_dir string
---@return string? target Normalized absolute target directory.
---@return string? err
local function normalize_target(target_dir)
    if type(target_dir) ~= 'string' or target_dir == '' then
        return nil, 'target_dir must be a non-empty string'
    end
    if target_dir:find('%z') ~= nil then
        return nil, 'target_dir contains NUL'
    end
    local norm = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(target_dir), ':p'))
    if norm ~= '/' then
        norm = norm:gsub('/+$', '')
    end
    return norm, nil
end

---Write one file atomically: temp file in the same directory, then rename.
---@param final string Absolute destination path.
---@param content string Exact bytes.
---@return boolean? ok
---@return string? err
local function commit_file(final, content)
    assert(type(final) == 'string', 'commit_file expects a path')
    assert(type(content) == 'string', 'commit_file expects content')
    vim.fn.mkdir(vim.fn.fnamemodify(final, ':h'), 'p')
    local tmp = final .. '.builder-tmp'
    local lines = vim.split(content, '\n', { plain = true })
    -- 'b': binary mode writes bytes exactly; a trailing empty item keeps
    -- the final newline, so the round-trip is byte-identical.
    if vim.fn.writefile(lines, tmp, 'b') ~= 0 then
        return nil, 'write failed'
    end
    if vim.fn.rename(tmp, final) ~= 0 then
        pcall(vim.fn.delete, tmp)
        return nil, 'rename failed'
    end
    return true, nil
end

---@class BuilderWriteState
---@field index integer Next file to process (1-based).
---@field created string[] Absolute paths written.
---@field skipped string[] Relative paths skipped.

-- Forward declaration: write_next recurses through UI callbacks.
---@type function
local write_next

---@param files table Validated file list.
---@param finals string[] Absolute destination per file.
---@param state BuilderWriteState
---@param ui table select(items, opts, on_choice) UI backend.
---@param on_done fun(result: table)
local function advance(files, finals, state, ui, on_done)
    state.index = state.index + 1
    write_next(files, finals, state, ui, on_done)
end

---@param files table
---@param finals string[]
---@param state BuilderWriteState
---@param ui table
---@param on_done fun(result: table)
write_next = function(files, finals, state, ui, on_done)
    local file = files[state.index]
    if file == nil then
        on_done({ status = 'done', created = state.created, skipped = state.skipped })
        return
    end
    local final = finals[state.index]
    assert(type(final) == 'string', 'finals must parallel files')
    if vim.uv.fs_stat(final) == nil then
        local ok, err = commit_file(final, file.content)
        if not ok then
            on_done({ status = 'error', message = 'write ' .. file.path .. ': ' .. tostring(err) })
            return
        end
        state.created[#state.created + 1] = final
        advance(files, finals, state, ui, on_done)
        return
    end
    -- Second explicit confirmation before overwriting an existing file.
    local prompt = 'Exists: ' .. file.path
    ui.select({ 'overwrite', 'skip', 'abort' }, { prompt = prompt }, function(choice)
        if choice == 'overwrite' then
            local ok, err = commit_file(final, file.content)
            if not ok then
                local message = 'write ' .. file.path .. ': ' .. tostring(err)
                on_done({ status = 'error', message = message })
                return
            end
            state.created[#state.created + 1] = final
            advance(files, finals, state, ui, on_done)
        elseif choice == 'skip' then
            state.skipped[#state.skipped + 1] = file.path
            advance(files, finals, state, ui, on_done)
        else
            on_done({ status = 'aborted', created = state.created, skipped = state.skipped })
        end
    end)
end

---Write validated files under target_dir. Existing files trigger a
---per-file overwrite/skip/abort confirmation through ui.
---@param files table Validated BuilderFile list.
---@param target_dir string Destination directory (created with mkdir -p).
---@param ui table select(items, opts, on_choice) UI backend.
---@param on_done fun(result: table) {status, created?, skipped?, message?}
function M.write_files(files, target_dir, ui, on_done)
    assert(type(ui) == 'table', 'writer.write_files expects a ui backend')
    assert(type(on_done) == 'function', 'writer.write_files expects a callback')
    local target, target_err = normalize_target(target_dir)
    if target == nil then
        on_done({ status = 'error', message = target_err })
        return
    end
    local valid, valid_err = M.validate_files(files)
    if not valid then
        on_done({ status = 'error', message = valid_err })
        return
    end
    -- Resolve and containment-check every destination before writing any.
    local finals = {}
    for _, file in ipairs(files) do
        local final = vim.fs.normalize(target .. '/' .. file.path)
        if final:sub(1, #target + 1) ~= target .. '/' then
            on_done({ status = 'error', message = 'path escapes target: ' .. file.path })
            return
        end
        finals[#finals + 1] = final
    end
    local state = { index = 1, created = {}, skipped = {} }
    write_next(files, finals, state, ui, on_done)
end

return M
