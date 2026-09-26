-- /qompassai/Diver/lua/ai/builder/menu.lua
-- Qompass AI Interactive Application Builder: Option Gathering (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Collects a BuilderSpec through vim.ui.select menus (project type,
-- language, features multi-pick, model) plus vim.ui.input free write-in
-- fields. M.validate/1 is pure and unit-testable; M.interactive/1 chains
-- the prompts with callbacks, validates the finished spec, and restarts
-- the questionnaire when validation fails.

local M = {}

---@class BuilderSpec
---@field name string Project name; also the default target directory leaf.
---@field project_type string One of M.PROJECT_TYPES.
---@field project_type_detail? string Required when project_type is 'other'.
---@field language string One of M.LANGUAGES.
---@field language_detail? string Required when language is 'other'.
---@field features string[] Subset of M.FEATURES, in pick order.
---@field model string Chosen model name or provider fallback label.
---@field target_dir string Where writer.lua will create files.
---@field write_in? string Free-form notes; anything the menus missed.

M.PROJECT_TYPES = {
    'cli-app',
    'neovim-plugin',
    'web-service',
    'tui',
    'library',
    'game-love2d',
    'other',
}

M.LANGUAGES = {
    'lua',
    'python',
    'typescript',
    'go',
    'rust',
    'zig',
    'other',
}

M.FEATURES = {
    'tests',
    'docs',
    'readme',
    'license',
    'gitignore',
    'ci-config',
    'linting',
    'dockerfile',
}

-- Used only when no local Ollama models are found. These are plain menu
-- labels, not verified provider endpoints.
M.PROVIDER_FALLBACK_MODELS = {
    'openai/gpt-5',
    'anthropic/claude-opus-4-6',
    'google/gemini-3-pro',
    'xai/grok-4',
}

local NAME_LEN_MAX = 64
local DETAIL_LEN_MAX = 256
local WRITEIN_LEN_MAX = 2000
local DIR_LEN_MAX = 512
local MODEL_COUNT_MAX = 32
local PROBE_TIMEOUT_MS = 5000

---@param list string[]
---@param value string?
---@return boolean
local function contains(list, value)
    assert(type(list) == 'table', 'contains expects a list')
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

---@param output string Raw stdout of `ollama list`.
---@return string[] models Model names, header skipped, bounded.
local function parse_ollama_list(output)
    assert(type(output) == 'string', 'parse_ollama_list expects a string')
    local models = {}
    for line in output:gmatch('[^\n]+') do
        local name = line:match('^%s*(%S+)')
        if name ~= nil and name ~= 'NAME' and #models < MODEL_COUNT_MAX then
            models[#models + 1] = name
        end
    end
    return models
end

---List candidate models: local Ollama models when the `ollama` binary is
---present and answers, otherwise the provider fallback labels.
---@return string[] models Never empty.
function M.probe_models()
    if vim.fn.executable('ollama') == 1 then
        local ok, result = pcall(function()
            return vim.system({ 'ollama', 'list' }, { text = true }):wait(PROBE_TIMEOUT_MS)
        end)
        if ok and type(result) == 'table' and result.code == 0 then
            local models = parse_ollama_list(result.stdout or '')
            if #models > 0 then
                return models
            end
        end
    end
    return vim.deepcopy(M.PROVIDER_FALLBACK_MODELS)
end

---Validate a spec table. Pure: no I/O, no UI.
---@param spec table Candidate spec.
---@return boolean? ok
---@return string? err
function M.validate(spec)
    if type(spec) ~= 'table' then
        return nil, 'spec must be a table'
    end
    if type(spec.name) ~= 'string' or spec.name == '' then
        return nil, 'spec.name must be a non-empty string'
    end
    if #spec.name > NAME_LEN_MAX then
        return nil, 'spec.name exceeds length bound'
    end
    if not contains(M.PROJECT_TYPES, spec.project_type) then
        return nil, 'spec.project_type is not a known option'
    end
    if spec.project_type == 'other' then
        if type(spec.project_type_detail) ~= 'string' or spec.project_type_detail == '' then
            return nil, "spec.project_type_detail is required when project_type is 'other'"
        end
        if #spec.project_type_detail > DETAIL_LEN_MAX then
            return nil, 'spec.project_type_detail exceeds length bound'
        end
    end
    if not contains(M.LANGUAGES, spec.language) then
        return nil, 'spec.language is not a known option'
    end
    if spec.language == 'other' then
        if type(spec.language_detail) ~= 'string' or spec.language_detail == '' then
            return nil, "spec.language_detail is required when language is 'other'"
        end
        if #spec.language_detail > DETAIL_LEN_MAX then
            return nil, 'spec.language_detail exceeds length bound'
        end
    end
    if type(spec.features) ~= 'table' then
        return nil, 'spec.features must be a list'
    end
    for _, feature in ipairs(spec.features) do
        if not contains(M.FEATURES, feature) then
            return nil, 'unknown feature: ' .. tostring(feature)
        end
    end
    if type(spec.model) ~= 'string' or spec.model == '' then
        return nil, 'spec.model must be a non-empty string'
    end
    if type(spec.target_dir) ~= 'string' or spec.target_dir == '' then
        return nil, 'spec.target_dir must be a non-empty string'
    end
    if #spec.target_dir > DIR_LEN_MAX then
        return nil, 'spec.target_dir exceeds length bound'
    end
    if spec.target_dir:find('%z') ~= nil then
        return nil, 'spec.target_dir contains NUL'
    end
    if spec.write_in ~= nil then
        if type(spec.write_in) ~= 'string' then
            return nil, 'spec.write_in must be a string'
        end
        if #spec.write_in > WRITEIN_LEN_MAX then
            return nil, 'spec.write_in exceeds length bound'
        end
    end
    return true, nil
end

-- Forward declarations: the questionnaire is a linear chain, each step
-- invoking the next from its UI callback.
---@type fun(spec: table, on_done: fun(spec: table?, err: string?)): nil
local ask_project_type
---@type fun(spec: table, on_done: fun(spec: table?, err: string?)): nil
local ask_project_language
---@type fun(spec: table, chosen: string[], on_done: fun(spec: table?, err: string?)): nil
local ask_features
---@type fun(spec: table, on_done: fun(spec: table?, err: string?)): nil
local ask_model
---@type fun(spec: table, on_done: fun(spec: table?, err: string?)): nil
local ask_target_dir
---@type fun(spec: table, on_done: fun(spec: table?, err: string?)): nil
local ask_write_in

---@param spec table
---@param on_done fun(spec: table?, err: string?)
local function finish(spec, on_done)
    local valid, err = M.validate(spec)
    if not valid then
        vim.notify('builder: ' .. tostring(err) .. ' -- restarting', vim.log.levels.WARN)
        M.interactive(on_done)
        return
    end
    on_done(spec, nil)
end

ask_write_in = function(spec, on_done)
    vim.ui.input({ prompt = 'Free write-in (anything the menus missed): ' }, function(text)
        if text == nil then
            on_done(nil, 'aborted by user')
            return
        end
        if text ~= '' then
            spec.write_in = text
        end
        finish(spec, on_done)
    end)
end

ask_target_dir = function(spec, on_done)
    local default = vim.fn.getcwd() .. '/' .. tostring(spec.name)
    vim.ui.input({ prompt = 'Target directory: ', default = default }, function(text)
        if text == nil or text == '' then
            on_done(nil, 'aborted by user')
            return
        end
        spec.target_dir = text
        ask_write_in(spec, on_done)
    end)
end

ask_model = function(spec, on_done)
    local models = M.probe_models()
    vim.ui.select(models, { prompt = 'Model:' }, function(choice)
        if choice == nil then
            on_done(nil, 'aborted by user')
            return
        end
        spec.model = choice
        ask_target_dir(spec, on_done)
    end)
end

ask_features = function(spec, chosen, on_done)
    local items = {}
    for _, feature in ipairs(M.FEATURES) do
        if not contains(chosen, feature) then
            items[#items + 1] = feature
        end
    end
    items[#items + 1] = '[done]'
    vim.ui.select(items, { prompt = 'Features ([done] to finish):' }, function(choice)
        if choice == nil then
            on_done(nil, 'aborted by user')
        elseif choice == '[done]' then
            spec.features = chosen
            ask_model(spec, on_done)
        else
            chosen[#chosen + 1] = choice
            ask_features(spec, chosen, on_done)
        end
    end)
end

ask_project_language = function(spec, on_done)
    vim.ui.select(M.LANGUAGES, { prompt = 'Language:' }, function(choice)
        if choice == nil then
            on_done(nil, 'aborted by user')
            return
        end
        spec.language = choice
        if choice == 'other' then
            vim.ui.input({ prompt = 'Which language? ' }, function(detail)
                if detail == nil or detail == '' then
                    on_done(nil, 'aborted by user')
                    return
                end
                spec.language_detail = detail
                ask_features(spec, {}, on_done)
            end)
            return
        end
        ask_features(spec, {}, on_done)
    end)
end

ask_project_type = function(spec, on_done)
    vim.ui.select(M.PROJECT_TYPES, { prompt = 'Project type:' }, function(choice)
        if choice == nil then
            on_done(nil, 'aborted by user')
            return
        end
        spec.project_type = choice
        if choice == 'other' then
            vim.ui.input({ prompt = 'Describe the project type: ' }, function(detail)
                if detail == nil or detail == '' then
                    on_done(nil, 'aborted by user')
                    return
                end
                spec.project_type_detail = detail
                ask_project_language(spec, on_done)
            end)
            return
        end
        ask_project_language(spec, on_done)
    end)
end

---@param spec table
---@param on_done fun(spec: table?, err: string?)
local function ask_name(spec, on_done)
    vim.ui.input({ prompt = 'Project name: ' }, function(text)
        if text == nil or text == '' then
            on_done(nil, 'aborted by user')
            return
        end
        spec.name = text
        ask_project_type(spec, on_done)
    end)
end

---Run the interactive questionnaire. Calls on_done(spec) with a validated
---spec, or on_done(nil, err) when the user aborts a prompt.
---@param on_done fun(spec: table?, err: string?)
function M.interactive(on_done)
    assert(type(on_done) == 'function', 'menu.interactive expects a callback')
    ask_name({}, on_done)
end

return M
