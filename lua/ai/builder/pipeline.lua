-- /qompassai/Diver/lua/ai/builder/pipeline.lua
-- Qompass AI Interactive Application Builder: Plan/Generate/Validate/Review (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The interactive build loop. Each stage (plan, generate, validate,
-- review) produces an artifact and then STOPS: the user must answer
-- yes/edit/abort before the next stage runs. Nothing is generated or
-- written without an explicit confirmation, and the generation backend
-- is never faked -- when ai.rose (Module 1) is absent the pipeline
-- reports "generation backend unavailable" and stops.
--
-- Stage overview:
--   plan      backend.plan({spec}, on_done) -> plan text; edit rewrites the text.
--   generate  backend.generate({spec, plan}, on_done) -> file list; edit attaches a
--             revision note and regenerates (bounded revision count).
--   validate  real checkers only (lua: load(); python: py_compile;
--             go: gofmt -e), each probed with vim.fn.executable; missing
--             checkers are reported as skipped, never as passed.
--   review    summary of files; yes hands off to writer.write_files,
--             which asks its own overwrite confirmations.
--
-- After every stage the session is persisted to a bounded JSON file
-- under stdpath('data') so :AiBuildResume can continue where the user
-- left off. UI, backend, and writer are injectable for headless tests.

local menu = require('ai.builder.menu')
local writer = require('ai.builder.writer')

local M = {}

---@class BuilderUi
---@field select fun(items: string[], opts: table, on_choice: fun(choice: string?)): nil
---@field input fun(prompt: string, default: string?, on_text: fun(text: string?)): nil

---@class BuilderBackend
---@field plan fun(opts: table, on_done: fun(err: string?, plan: string?)): table?
---@field generate fun(opts: table, on_done: fun(err: string?, files: table?)): table?

---@class BuilderOverrides
---@field ui BuilderUi? UI backend; defaults to vim.ui.select/vim.ui.input.
---@field backend BuilderBackend? Generation backend; defaults to ai.rose.
---@field write fun(files: table, target_dir: string, ui: table, on_done: fun(result: table))?

---@class BuilderSession
---@field spec table BuilderSpec plus revision_note/style_note.
---@field stage string One of STAGE_ORDER.
---@field plan string?
---@field files table?
---@field validation table?
---@field revisions table<string, integer>

local STAGE_ORDER = { 'plan', 'generate', 'validate', 'review' }

local REVISION_COUNT_MAX = 5
local SUMMARY_LINES_MAX = 20
local MESSAGE_LEN_MAX = 500
local SESSION_SIZE_BYTES_MAX = 262144
local VALIDATE_TIMEOUT_MS = 15000
local VALIDATE_FILE_SIZE_BYTES_MAX = 1048576

---@type BuilderUi
local default_ui = {
    select = function(items, opts, on_choice)
        vim.ui.select(items, opts, on_choice)
    end,
    input = function(prompt, default, on_text)
        vim.ui.input({ prompt = prompt, default = default }, on_text)
    end,
}

---@param stage string
---@return string? next Stage following `stage`, or nil after review.
local function next_stage(stage)
    assert(type(stage) == 'string', 'next_stage expects a stage name')
    for index, name in ipairs(STAGE_ORDER) do
        if name == stage then
            return STAGE_ORDER[index + 1]
        end
    end
    return nil
end

---@param env table {ui=..., backend=..., write=..., overrides=...}
---@param title string Confirmation prompt, may be multi-line.
---@param on_decision fun(decision: string) 'yes' | 'edit' | 'abort'
local function ask_confirm(env, title, on_decision)
    assert(type(env.ui) == 'table', 'env.ui must be a UI backend')
    env.ui.select({ 'yes', 'edit', 'abort' }, { prompt = title }, function(choice)
        if choice == 'yes' or choice == 'edit' then
            on_decision(choice)
        else
            on_decision('abort') -- dismissed prompt counts as abort
        end
    end)
end

---@param files table
---@param header string
---@return string
local function file_list_text(files, header)
    local lines = { header }
    for index, file in ipairs(files) do
        if index > SUMMARY_LINES_MAX then
            lines[#lines + 1] = '... (' .. (#files - SUMMARY_LINES_MAX) .. ' more)'
            break
        end
        local size_bytes = #tostring(file.content)
        lines[#lines + 1] = string.format('%s (%d bytes)', tostring(file.path), size_bytes)
    end
    return table.concat(lines, '\n')
end

---@param session BuilderSession
---@return string
local function plan_title(session)
    local lines = { 'Build plan -- yes to generate, edit to revise, abort to stop:' }
    for index, line in ipairs(vim.split(session.plan or '', '\n', { plain = true })) do
        if index > SUMMARY_LINES_MAX then
            lines[#lines + 1] = '...'
            break
        end
        lines[#lines + 1] = line
    end
    return table.concat(lines, '\n')
end

---@param report table Array of {path, status, checker, message}.
---@return string
local function validation_title(report)
    local pass, fail, skip = 0, 0, 0
    local lines = {}
    for _, entry in ipairs(report) do
        if entry.status == 'pass' then
            pass = pass + 1
        elseif entry.status == 'fail' then
            fail = fail + 1
        else
            skip = skip + 1
        end
        if #lines < SUMMARY_LINES_MAX then
            local message = tostring(entry.message):sub(1, MESSAGE_LEN_MAX)
            lines[#lines + 1] = string.format(
                '[%s] %s (%s): %s',
                tostring(entry.status),
                tostring(entry.path),
                tostring(entry.checker),
                message
            )
        end
    end
    local header = table.concat({
        string.format('Validation: %d pass, %d fail, %d skip', pass, fail, skip),
        'yes to review, edit to regenerate, abort to stop:',
    }, ' -- ')
    table.insert(lines, 1, header)
    return table.concat(lines, '\n')
end

-- ---------------------------------------------------------------------------
-- Generation backend: ai.rose (Module 1). Absent or mismatched backends
-- report cleanly; output is never invented.
-- ---------------------------------------------------------------------------

---Resolve the generation backend: an injected override, else ai.rose when
---it exposes the asynchronous plan()/generate() entry points.
---@return BuilderBackend? backend
---@return string? err
function M.resolve_backend()
    local ok, rose = pcall(require, 'ai.rose')
    if not ok then
        return nil, 'generation backend unavailable: ai.rose is not loaded (Module 1)'
    end
    if type(rose) ~= 'table' then
        return nil, 'generation backend unavailable: ai.rose is not a module table'
    end
    if type(rose.plan) == 'function' and type(rose.generate) == 'function' then
        return { plan = rose.plan, generate = rose.generate }, nil
    end
    local model = rose.model
    local model_has_api = type(model) == 'table'
        and type(model.plan) == 'function'
        and type(model.generate) == 'function'
    if model_has_api then
        return { plan = model.plan, generate = model.generate }, nil
    end
    return nil, 'generation backend unavailable: ai.rose exposes no plan()/generate() entry points'
end

---Note for the plan stage when a tiger-style guide exists for the language.
---@param language string?
---@return string?
function M.style_note(language)
    if type(language) ~= 'string' or language == '' then
        return nil
    end
    if language:find('[^%w%-]') ~= nil then
        return nil
    end
    local guide = vim.fn.expand('~/workspace/skills/tiger-style-' .. language .. '/SKILL.md')
    if vim.uv.fs_stat(guide) == nil then
        return nil
    end
    return 'Tiger Style guide applies to generated ' .. language .. ' code: ' .. guide
end

-- ---------------------------------------------------------------------------
-- Validation: real checkers only, probed with vim.fn.executable.
-- ---------------------------------------------------------------------------

---@param path string
---@param content string
---@return boolean ok
---@return string message
local function check_lua(path, content)
    assert(type(path) == 'string', 'check_lua expects a path')
    assert(type(content) == 'string', 'check_lua expects content')
    local chunk, err = load(content, '@' .. path)
    if chunk == nil then
        return false, 'lua syntax error: ' .. tostring(err)
    end
    return true, 'lua load() syntax check passed'
end

---@param exe string
---@param args string[]
---@param ext string Temp file extension.
---@param content string
---@return boolean? ok nil when the checker could not run (skip).
---@return string message
local function check_with_tmp(exe, args, ext, content)
    if #content > VALIDATE_FILE_SIZE_BYTES_MAX then
        return nil, 'skipped: file exceeds size bound'
    end
    local tmp = vim.fn.tempname() .. '.' .. ext
    if vim.fn.writefile(vim.split(content, '\n', { plain = true }), tmp, 'b') ~= 0 then
        return nil, 'skipped: could not stage temp file'
    end
    local argv = { exe }
    for _, arg in ipairs(args) do
        argv[#argv + 1] = arg
    end
    argv[#argv + 1] = tmp
    local ok, result = pcall(function()
        return vim.system(argv, { text = true }):wait(VALIDATE_TIMEOUT_MS)
    end)
    vim.fn.delete(tmp)
    if not ok or type(result) ~= 'table' then
        return nil, 'skipped: checker did not run'
    end
    if result.code == 0 then
        return true, exe .. ' check passed'
    end
    local detail = result.stderr ~= '' and result.stderr or result.stdout or ''
    return false, exe .. ' failed: ' .. detail:sub(1, MESSAGE_LEN_MAX)
end

---@class BuilderValidationEntry
---@field path string
---@field status 'pass'|'fail'|'skip'
---@field checker string
---@field message string

---Validate generated files with real checkers. Missing checkers are
---reported as skipped, never as passed.
---@param files table[]
---@return BuilderValidationEntry[] report
function M.validate_files(files)
    assert(type(files) == 'table', 'validate_files expects a file list')
    local report = {}
    for _, file in ipairs(files) do
        local path = tostring(file.path or '?')
        local content = tostring(file.content or '')
        local entry = {
            path = path,
            status = 'skip',
            checker = 'none',
            message = 'no checker available',
        }
        local ext = path:match('%.([%w]+)$')
        if ext == 'lua' then
            local ok, message = check_lua(path, content)
            entry.status = ok and 'pass' or 'fail'
            entry.checker = 'lua:load()'
            entry.message = message
        elseif ext == 'py' and vim.fn.executable('python3') == 1 then
            local ok, message = check_with_tmp('python3', { '-m', 'py_compile' }, 'py', content)
            entry.status = ok == nil and 'skip' or (ok and 'pass' or 'fail')
            entry.checker = 'python3:py_compile'
            entry.message = message
        elseif ext == 'go' and vim.fn.executable('gofmt') == 1 then
            local ok, message = check_with_tmp('gofmt', { '-e' }, 'go', content)
            entry.status = ok == nil and 'skip' or (ok and 'pass' or 'fail')
            entry.checker = 'gofmt:-e'
            entry.message = message
        end
        report[#report + 1] = entry
    end
    return report
end

-- ---------------------------------------------------------------------------
-- Session persistence: bounded JSON under stdpath('data').
-- ---------------------------------------------------------------------------

---@return string path
local function session_path()
    return vim.fn.stdpath('data') .. '/diver/builder-session.json'
end

---@param session BuilderSession
---@return boolean? ok
---@return string? err
function M.save_session(session)
    assert(type(session) == 'table', 'save_session expects a session table')
    local payload = {
        stage = session.stage,
        spec = session.spec,
        plan = session.plan,
        revisions = session.revisions,
    }
    -- Keep the session bounded: drop bulky artifacts when too large.
    local artifact_bytes = 0
    if type(session.files) == 'table' then
        for _, file in ipairs(session.files) do
            artifact_bytes = artifact_bytes + #tostring(file.content or '')
        end
    end
    if artifact_bytes <= SESSION_SIZE_BYTES_MAX then
        payload.files = session.files
        payload.validation = session.validation
    end
    local ok, encoded = pcall(vim.json.encode, payload)
    if not ok then
        return nil, 'session encode failed: ' .. tostring(encoded)
    end
    assert(type(encoded) == 'string', 'vim.json.encode must return a string')
    if #encoded > SESSION_SIZE_BYTES_MAX then
        return nil, 'session payload exceeds size bound'
    end
    local path = session_path()
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    local tmp = path .. '.tmp'
    if vim.fn.writefile(vim.split(encoded, '\n', { plain = true }), tmp, 'b') ~= 0 then
        return nil, 'session write failed'
    end
    if vim.fn.rename(tmp, path) ~= 0 then
        pcall(vim.fn.delete, tmp)
        return nil, 'session rename failed'
    end
    return true, nil
end

---Best-effort persist; a failed save warns but never aborts the build.
---@param session BuilderSession
local function persist(session)
    local _, err = M.save_session(session)
    if err ~= nil then
        vim.notify('builder: session save failed: ' .. err, vim.log.levels.WARN)
    end
end

---Load the last session. Validates the JSON shape and the spec.
---@return BuilderSession? session
---@return string? err
function M.load_session()
    local path = session_path()
    local stat = vim.uv.fs_stat(path)
    if stat == nil then
        return nil, 'no saved builder session'
    end
    if stat.size > SESSION_SIZE_BYTES_MAX then
        return nil, 'saved session exceeds size bound'
    end
    local read_ok, lines = pcall(vim.fn.readfile, path)
    if not read_ok or type(lines) ~= 'table' then
        return nil, 'saved session is unreadable'
    end
    local decode_ok, decoded = pcall(vim.json.decode, table.concat(lines, '\n'))
    if not decode_ok or type(decoded) ~= 'table' then
        return nil, 'saved session is not valid JSON'
    end
    if type(decoded.spec) ~= 'table' then
        return nil, 'saved session has no spec'
    end
    local valid, valid_err = menu.validate(decoded.spec)
    if not valid then
        return nil, 'saved session spec invalid: ' .. tostring(valid_err)
    end
    if not next_stage(decoded.stage or '') and decoded.stage ~= 'review' then
        return nil, 'saved session has unknown stage'
    end
    return decoded, nil
end

-- ---------------------------------------------------------------------------
-- The stage loop. Forward declarations: stages call each other through
-- UI callbacks, so the dispatcher is declared before the stages.
-- ---------------------------------------------------------------------------

---@type fun(session: BuilderSession, env: table, stage: string, on_done: fun(result: table)): nil
local run_stage
---@type function
local confirm_and_advance

---@param session BuilderSession
---@param env table
---@param on_done fun(result: table)
local function finish_review(session, env, on_done)
    env.write(session.files or {}, session.spec.target_dir, env.ui, function(result)
        on_done({ status = 'done', created = result.created, skipped = result.skipped })
    end)
end

---@param session BuilderSession
---@param env table
---@param stage string
---@param on_done fun(result: table)
local function handle_edit(session, env, stage, on_done)
    local count = (session.revisions[stage] or 0) + 1
    if count > REVISION_COUNT_MAX then
        local message = 'revision limit exceeded for ' .. stage
        on_done({ status = 'error', stage = stage, message = message })
        return
    end
    session.revisions[stage] = count
    if stage == 'plan' then
        env.ui.input('Edit plan text:', session.plan or '', function(text)
            if text == nil then
                on_done({ status = 'aborted', stage = stage })
                return
            end
            session.plan = text
            persist(session)
            confirm_and_advance(env, session, stage, plan_title(session), on_done)
        end)
        return
    end
    env.ui.input('Revision note for ' .. stage .. ':', '', function(note)
        if note == nil then
            on_done({ status = 'aborted', stage = stage })
            return
        end
        session.spec.revision_note = note
        session.stage = 'generate'
        persist(session)
        run_stage(session, env, 'generate', on_done)
    end)
end

---@param env table
---@param session BuilderSession
---@param stage string
---@param title string
---@param on_done fun(result: table)
confirm_and_advance = function(env, session, stage, title, on_done)
    ask_confirm(env, title, function(decision)
        if decision == 'yes' then
            local following = next_stage(stage)
            if following == nil then
                finish_review(session, env, on_done)
            else
                session.stage = following
                persist(session)
                run_stage(session, env, following, on_done)
            end
        elseif decision == 'edit' then
            handle_edit(session, env, stage, on_done)
        else
            on_done({ status = 'aborted', stage = stage })
        end
    end)
end

---@param session BuilderSession
---@param env table
---@param on_done fun(result: table)
local function stage_plan(session, env, on_done)
    local backend = env.backend
    local backend_err
    if backend == nil then
        backend, backend_err = M.resolve_backend()
    end
    if backend == nil then
        on_done({ status = 'error', stage = 'plan', message = backend_err })
        return
    end
    env.backend = backend
    -- The backend is asynchronous: plan text arrives through on_done, and
    -- the stage only advances after the yes/edit/abort confirmation.
    local requested, request_err = pcall(backend.plan, { spec = session.spec }, function(err, plan_text)
        if err ~= nil then
            on_done({ status = 'error', stage = 'plan', message = tostring(err) })
            return
        end
        if type(plan_text) ~= 'string' or plan_text:match('^%s*$') then
            on_done({ status = 'error', stage = 'plan', message = 'plan backend returned no text' })
            return
        end
        session.plan = plan_text
        session.stage = 'plan'
        persist(session)
        confirm_and_advance(env, session, 'plan', plan_title(session), on_done)
    end)
    if not requested then
        on_done({
            status = 'error',
            stage = 'plan',
            message = 'plan backend raised: ' .. tostring(request_err),
        })
    end
end

---@param session BuilderSession
---@param env table
---@param on_done fun(result: table)
local function stage_generate(session, env, on_done)
    if env.backend == nil then
        local backend, backend_err = M.resolve_backend()
        if backend == nil then
            on_done({ status = 'error', stage = 'generate', message = backend_err })
            return
        end
        env.backend = backend
    end
    if session.plan == nil then
        on_done({ status = 'error', stage = 'generate', message = 'no plan artifact' })
        return
    end
    local requested, request_err = pcall(
        env.backend.generate,
        { spec = session.spec, plan = session.plan },
        function(err, files)
            if err ~= nil then
                on_done({ status = 'error', stage = 'generate', message = tostring(err) })
                return
            end
            local valid, valid_err = writer.validate_files(files)
            if not valid then
                local message = 'backend output: ' .. tostring(valid_err)
                on_done({ status = 'error', stage = 'generate', message = message })
                return
            end
            session.files = files
            session.stage = 'generate'
            persist(session)
            local header = 'Generated files -- yes to validate, edit to revise, abort to stop:'
            local title = file_list_text(files, header)
            confirm_and_advance(env, session, 'generate', title, on_done)
        end
    )
    if not requested then
        on_done({
            status = 'error',
            stage = 'generate',
            message = 'generate backend raised: ' .. tostring(request_err),
        })
    end
end

---@param session BuilderSession
---@param env table
---@param on_done fun(result: table)
local function stage_validate(session, env, on_done)
    local report = M.validate_files(session.files or {})
    session.validation = report
    session.stage = 'validate'
    persist(session)
    confirm_and_advance(env, session, 'validate', validation_title(report), on_done)
end

---@param session BuilderSession
---@param env table
---@param on_done fun(result: table)
local function stage_review(session, env, on_done)
    session.stage = 'review'
    persist(session)
    local header = 'Review -- target: '
        .. tostring(session.spec.target_dir)
        .. ' -- yes writes files, edit regenerates, abort stops:'
    local title = file_list_text(session.files or {}, header)
    confirm_and_advance(env, session, 'review', title, on_done)
end

run_stage = function(session, env, stage, on_done)
    if stage == 'plan' then
        stage_plan(session, env, on_done)
    elseif stage == 'generate' then
        stage_generate(session, env, on_done)
    elseif stage == 'validate' then
        stage_validate(session, env, on_done)
    elseif stage == 'review' then
        stage_review(session, env, on_done)
    else
        on_done({ status = 'error', stage = stage, message = 'unknown stage' })
    end
end

---@param overrides BuilderOverrides?
---@return table env
local function build_env(overrides)
    overrides = overrides or {}
    return {
        ui = overrides.ui or default_ui,
        backend = overrides.backend,
        write = overrides.write or writer.write_files,
    }
end

---Run the full plan -> generate -> validate -> review loop with a fresh
---session. Stops for yes/edit/abort at every stage.
---@param spec table Validated BuilderSpec.
---@param overrides BuilderOverrides?
---@param on_done fun(result: table) {status='done'|'aborted'|'error', ...}
function M.run(spec, overrides, on_done)
    assert(type(spec) == 'table', 'pipeline.run expects a spec table')
    assert(type(on_done) == 'function', 'pipeline.run expects a callback')
    local valid, valid_err = menu.validate(spec)
    if not valid then
        local message = 'invalid spec: ' .. tostring(valid_err)
        on_done({ status = 'error', stage = 'plan', message = message })
        return
    end
    local session = {
        spec = vim.deepcopy(spec),
        stage = 'plan',
        plan = nil,
        files = nil,
        validation = nil,
        revisions = {},
    }
    -- The plan stage notes the tiger-style guide when one exists, so the
    -- backend can generate conforming code.
    session.spec.style_note = M.style_note(session.spec.language)
    -- SCIP context is advisory and async: when the spec names a language
    -- with a SCIP indexer, ensure a fresh index exists before generation
    -- so the backend can reference precise project symbols. A missing
    -- indexer never blocks the build.
    local ok_scip, builder_scip = pcall(require, 'ai.builder.scip')

    if ok_scip then
        builder_scip.attach(session.spec, function()
            run_stage(session, build_env(overrides), 'plan', on_done)
        end)
        return
    end

    run_stage(session, build_env(overrides), 'plan', on_done)
end

---Resume a session loaded with M.load_session. Missing artifacts fall
---back to the earliest stage that can rebuild them.
---@param session BuilderSession
---@param overrides BuilderOverrides?
---@param on_done fun(result: table)
function M.resume(session, overrides, on_done)
    assert(type(session) == 'table', 'pipeline.resume expects a session table')
    assert(type(on_done) == 'function', 'pipeline.resume expects a callback')
    local stage = session.stage
    if stage ~= 'plan' and stage ~= 'generate' and stage ~= 'validate' and stage ~= 'review' then
        on_done({ status = 'error', stage = 'resume', message = 'unknown session stage' })
        return
    end
    if session.revisions == nil then
        session.revisions = {}
    end
    if type(session.spec) ~= 'table' then
        on_done({ status = 'error', stage = 'resume', message = 'session has no spec' })
        return
    end
    if session.spec.style_note == nil then
        session.spec.style_note = M.style_note(session.spec.language)
    end
    if stage ~= 'plan' and session.plan == nil then
        stage = 'plan'
    elseif (stage == 'validate' or stage == 'review') and type(session.files) ~= 'table' then
        stage = 'generate'
    end
    session.stage = stage
    run_stage(session, build_env(overrides), stage, on_done)
end

return M
