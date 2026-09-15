-- /qompassai/Diver/lua/linters/npm_groovy_lint.lua
-- Native npm-groovy-lint linter and opt-in formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/nvuillam/npm-groovy-lint/tree/2080dffcddb215d409b149ccc7f595cb242a6209
local api = vim.api
local diagnostic = vim.diagnostic
local fs = vim.fs
local fn = vim.fn
local uv = vim.uv

local TOOLING = {
  executable = 'npm-groovy-lint',
  server_host = 'http://127.0.0.1',
  server_port = 7484,
  timeout_ms = 60000,
  transform_timeout_ms = 30000,
}
local ROOT_MARKERS = {
  '.groovylintrc',
  '.groovylintrc.json',
  '.groovylintrc.js',
  '.groovylintrc.cjs',
  '.groovylintrc.yml',
  '.groovylintrc.yaml',
  'settings.gradle',
  'settings.gradle.kts',
  'build.gradle',
  'gradlew',
  '.git',
}
local FILE_PATTERNS = {
  '*.gradle',
  '*.groovy',
  '*.jenkinsfile',
  'Jenkinsfile',
  'Jenkinsfile.*',
}
local LIMITS = {
  diagnostics = 512,
  issues = 511,
  message_bytes = 4096,
  output_bytes = 16 * 1024 * 1024,
  source_bytes = 4 * 1024 * 1024,
  files = 128,
  errors_per_file = 10000,
}
local SEVERITIES = {
  error = diagnostic.severity.ERROR,
  info = diagnostic.severity.INFO,
  warning = diagnostic.severity.WARN,
}
local SETUP_FIELDS = {
  format_on_save = true,
  notify = true,
  save_mode = true,
  server_host = true,
  server_port = true,
  transform_timeout_ms = true,
  use_server = true,
}

---@alias NpmGroovyLintMode 'fix'|'format'

---@class NpmGroovyLintIssue
---@field id? integer|string
---@field line? integer|string
---@field rule string
---@field severity string
---@field msg string
---@field fixable? boolean
---@field fixLabel? string
---@field range? NpmGroovyLintRange

---@class NpmGroovyLintPosition
---@field line? integer
---@field character? integer

---@class NpmGroovyLintRange
---@field start? NpmGroovyLintPosition
---@field end? NpmGroovyLintPosition

---@class NpmGroovyLintFileReport
---@field errors any[]

---@class NpmGroovyLintSetupOptions
---@field format_on_save? boolean
---@field notify? boolean
---@field save_mode? NpmGroovyLintMode
---@field server_host? string
---@field server_port? integer
---@field transform_timeout_ms? integer
---@field use_server? boolean

---@class NpmGroovyLintDefinition:Linter
---@field active_rules string[]
---@field fixable_rules string[]

local ACTIVE_RULES = {
  'AssignmentInConditional',
  'BlankLineBeforePackage',
  'BlockEndsWithBlankLine',
  'BlockStartsWithBlankLine',
  'BracesForClass',
  'BracesForForLoop',
  'BracesForIfElse',
  'BracesForMethod',
  'BracesForTryCatchFinally',
  'CatchException',
  'ClassEndsWithBlankLine',
  'ClassStartsWithBlankLine',
  'ClosingBraceNotAlone',
  'ConsecutiveBlankLines',
  'DuplicateImport',
  'DuplicateNumberLiteral',
  'DuplicateStringLiteral',
  'ElseBlockBraces',
  'ExplicitArrayListInstantiation',
  'ExplicitLinkedListInstantiation',
  'FileEndsWithoutNewline',
  'GStringExpressionWithinString',
  'IfStatementBraces',
  'Indentation',
  'IndentationClosingBraces',
  'IndentationComments',
  'InsecureRandom',
  'MethodCount',
  'MethodParameterTypeRequired',
  'MethodReturnTypeRequired',
  'MisorderedStaticImports',
  'MissingBlankLineAfterImports',
  'MissingBlankLineAfterPackage',
  'NoDef',
  'NoJavaUtilDate',
  'NoTabCharacter',
  'SimpleDateFormatMissingLocale',
  'SpaceAfterCatch',
  'SpaceAfterComma',
  'SpaceAfterFor',
  'SpaceAfterIf',
  'SpaceAfterMethodCallName',
  'SpaceAfterOpeningBrace',
  'SpaceAfterSemicolon',
  'SpaceAfterSwitch',
  'SpaceAfterWhile',
  'SpaceAroundOperator',
  'SpaceBeforeClosingBrace',
  'SpaceBeforeOpeningBrace',
  'SpaceInsideParentheses',
  'SystemExit',
  'TrailingWhitespace',
  'UnnecessaryDefInFieldDeclaration',
  'UnnecessaryDefInMethodDeclaration',
  'UnnecessaryDefInVariableDeclaration',
  'UnnecessaryDotClass',
  'UnnecessaryFinalOnPrivateMethod',
  'UnnecessaryGString',
  'UnnecessaryGroovyImport',
  'UnnecessaryPackageReference',
  'UnnecessaryParenthesesForMethodCallWithClosure',
  'UnnecessaryPublicModifier',
  'UnnecessarySemicolon',
  'UnnecessaryToString',
  'UnusedImport',
  'UnusedMethodParameter',
  'UnusedVariable',
  'VariableName',
  'VariableTypeRequired',
}

local FIXABLE_RULES = {
  'NoTabCharacter',
  'Indentation',
  'AssignmentInConditional',
  'UnnecessaryGString',
  'UnnecessaryToString',
  'ExplicitArrayListInstantiation',
  'ExplicitLinkedListInstantiation',
  'SpaceBeforeOpeningBrace',
  'SpaceAfterOpeningBrace',
  'SpaceAfterCatch',
  'SpaceAfterMethodCallName',
  'SpaceAfterSwitch',
  'SpaceAfterWhile',
  'SpaceAroundOperator',
  'SpaceAfterComma',
  'SpaceAfterSemicolon',
  'SpaceAfterFor',
  'SpaceAfterIf',
  'SpaceBeforeClosingBrace',
  'SpaceInsideParentheses',
  'UnnecessaryDefInFieldDeclaration',
  'UnnecessaryDefInMethodDeclaration',
  'UnnecessaryDefInVariableDeclaration',
  'UnnecessaryDotClass',
  'UnnecessaryFinalOnPrivateMethod',
  'UnnecessaryPackageReference',
  'UnnecessaryParenthesesForMethodCallWithClosure',
  'UnnecessarySemicolon',
  'TrailingWhitespace',
  'UnnecessaryGroovyImport',
  'UnusedImport',
  'InsecureRandom',
  'DuplicateImport',
  'BlankLineBeforePackage',
  'BlockStartsWithBlankLine',
  'BlockEndsWithBlankLine',
  'BracesForClass',
  'BracesForForLoop',
  'BracesForIfElse',
  'BracesForMethod',
  'BracesForTryCatchFinally',
  'ClassStartsWithBlankLine',
  'ClassEndsWithBlankLine',
  'MissingBlankLineAfterPackage',
  'MissingBlankLineAfterImports',
  'MisorderedStaticImports',
  'IfStatementBraces',
  'ElseBlockBraces',
  'ClosingBraceNotAlone',
  'IndentationClosingBraces',
  'IndentationComments',
  'ConsecutiveBlankLines',
  'FileEndsWithoutNewline',
}

---@type NpmGroovyLintDefinition
local M = {
  active_rules = vim.deepcopy(ACTIVE_RULES),
  cmd = TOOLING.executable,
  fixable_rules = vim.deepcopy(FIXABLE_RULES),
}

local runtime = {
  format_on_save = true,
  notify = true,
  save_mode = 'format',
  server_host = TOOLING.server_host,
  server_port = TOOLING.server_port,
  transform_timeout_ms = TOOLING.transform_timeout_ms,
  use_server = true,
}
local transforming = {}

local function validate_rule_inventory()
  assert(#ACTIVE_RULES == 69)
  assert(#FIXABLE_RULES == 53)

  local active = {}

  for _, name in ipairs(ACTIVE_RULES) do
    assert(active[name] == nil)
    active[name] = true
  end

  local fixable = {}

  for _, name in ipairs(FIXABLE_RULES) do
    assert(active[name] == true)
    assert(fixable[name] == nil)
    fixable[name] = true
  end
end

validate_rule_inventory()

---@param path string
---@param cwd string
---@return string
local function canonical(path, cwd)
  assert(type(path) == 'string')
  assert(type(cwd) == 'string')

  if path:sub(1, 1) ~= '/' then
    path = fs.joinpath(cwd, path)
  end

  path = fs.normalize(path)

  return uv.fs_realpath(path) or path
end

---@param filename string
---@return string
local function root_for_path(filename)
  return fs.root(filename, ROOT_MARKERS) or fs.dirname(filename) or uv.cwd() or '.'
end

---@param context LintContext
---@return string
local function root(context)
  return root_for_path(context.filename)
end

---@param arguments string[]
local function add_server_arguments(arguments)
  if runtime.use_server then
    arguments[#arguments + 1] = '--serverhost=' .. runtime.server_host
    arguments[#arguments + 1] = '--serverport=' .. tostring(runtime.server_port)
  else
    arguments[#arguments + 1] = '--noserver'
  end
end

---@param context LintContext
---@return string[]
local function lint_arguments(context)
  assert(context.filename ~= '')
  assert(not context.modified)

  local project_root = root(context)
  local filename = canonical(context.filename, project_root)
  local arguments = {
    '--output=json',
    '--failon=none',
    '--config=' .. project_root,
  }

  add_server_arguments(arguments)
  arguments[#arguments + 1] = '--'
  arguments[#arguments + 1] = filename

  return arguments
end

---@param value string
---@return string
local function clean(value)
  local message = vim.trim(value:gsub('[%z\1-\31\127]', ' '))

  if #message <= LIMITS.message_bytes then
    return message
  end

  local last = LIMITS.message_bytes - 3

  while last > 0 do
    local byte = message:byte(last + 1)

    if byte == nil or byte < 128 or byte >= 192 then
      break
    end

    last = last - 1
  end

  return message:sub(1, last) .. '...'
end

---@param value any
---@return integer?
local function integer(value)
  local parsed = tonumber(value)

  if parsed == nil or parsed ~= math.floor(parsed) then
    return nil
  end

  if parsed < 0 or parsed >= 2147483647 then
    return nil
  end

  ---@cast parsed integer
  return parsed
end

---@param context LintContext
---@param code string
---@param message string
---@param severity? integer
---@return vim.Diagnostic
local function status(context, code, message, severity)
  return {
    bufnr = context.bufnr,
    lnum = 0,
    end_lnum = 0,
    col = 0,
    end_col = 0,
    severity = severity or diagnostic.severity.WARN,
    source = 'npm-groovy-lint',
    code = code,
    message = clean(message),
  }
end

---@param bufnr integer
---@param line any
---@param character any
---@return integer, integer
local function position(bufnr, line, character)
  local reported_line = integer(line)
  local reported_character = integer(character) or 0
  local line_count = math.max(api.nvim_buf_line_count(bufnr), 1)
  local row = math.min(math.max((reported_line or 1) - 1, 0), line_count - 1)
  local text = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
  local column = vim.str_byteindex(text, 'utf-16', reported_character, false)

  return row, column
end

---@param context LintContext
---@param path any
---@return boolean
local function is_target(context, path)
  if type(path) ~= 'string' or path == '' or path:find('%z') ~= nil then
    return false
  end

  local project_root = root(context)
  local target = canonical(context.filename, project_root)

  return canonical(path, project_root) == target
end

---@param context LintContext
---@param issue any
---@return vim.Diagnostic?
---@return boolean malformed
local function parse_issue(context, issue)
  if
    type(issue) ~= 'table'
    or type(issue.rule) ~= 'string'
    or issue.rule == ''
    or type(issue.msg) ~= 'string'
    or issue.msg == ''
    or type(issue.severity) ~= 'string'
  then
    return nil, true
  end

  ---@cast issue NpmGroovyLintIssue
  local severity = SEVERITIES[issue.severity]
  local malformed = severity == nil
  local start_line = issue.line
  local start_character = 0
  local end_line = issue.line
  local end_character = 0

  if type(issue.range) == 'table' then
    if type(issue.range.start) == 'table' then
      start_line = issue.range.start.line or start_line
      start_character = issue.range.start.character or 0
    end

    if type(issue.range['end']) == 'table' then
      end_line = issue.range['end'].line or start_line
      end_character = issue.range['end'].character or start_character
    end
  elseif issue.range ~= nil then
    malformed = true
  end

  local row, column = position(context.bufnr, start_line, start_character)
  local end_row, end_column = position(context.bufnr, end_line, end_character)
  local item = status(context, clean(issue.rule), issue.msg, severity)

  item.lnum = row
  item.col = column
  item.end_lnum = math.max(end_row, row)

  if end_row < row then
    item.end_col = column
  elseif end_row == row then
    item.end_col = math.max(end_column, column)
  else
    item.end_col = end_column
  end

  item.user_data = {
    fixable = issue.fixable == true,
    fix_label = type(issue.fixLabel) == 'string' and clean(issue.fixLabel) or nil,
    id = issue.id,
  }

  return item, malformed
end

---@param values table
---@param count_max integer
---@return string[] keys
---@return boolean malformed
---@return boolean limited
local function sorted_string_keys(values, count_max)
  local keys = {}
  local malformed = false
  local limited = false

  for key in pairs(values) do
    if #keys >= count_max then
      limited = true
      break
    end

    if type(key) == 'string' then
      keys[#keys + 1] = key
    else
      malformed = true
    end
  end

  table.sort(keys)

  return keys, malformed, limited
end

---@param diagnostics vim.Diagnostic[]
---@param context LintContext
---@param file_report any
---@return boolean malformed
---@return boolean limited
local function append_file(diagnostics, context, file_report)
  if type(file_report) ~= 'table' or type(file_report.errors) ~= 'table' then
    return true, false
  end

  ---@cast file_report NpmGroovyLintFileReport
  if not vim.islist(file_report.errors) then
    return true, false
  end

  local malformed = false
  local limited = #file_report.errors > LIMITS.errors_per_file

  for index = 1, math.min(#file_report.errors, LIMITS.errors_per_file) do
    if #diagnostics >= LIMITS.issues then
      return malformed, true
    end

    local item, item_malformed = parse_issue(context, file_report.errors[index])

    malformed = malformed or item_malformed

    if item ~= nil then
      diagnostics[#diagnostics + 1] = item
    end
  end

  return malformed, limited
end

---@param diagnostics vim.Diagnostic[]
---@param item vim.Diagnostic
local function append_status(diagnostics, item)
  if #diagnostics < LIMITS.diagnostics then
    diagnostics[#diagnostics + 1] = item
  end
end

---@param output string
---@param context LintContext
---@return table<string, any>? files
---@return vim.Diagnostic? problem
local function decode_files(output, context)
  if #output > LIMITS.output_bytes then
    return nil, status(context, 'output-limit', 'npm-groovy-lint output exceeded 16 MiB.')
  end

  local text = vim.trim(output)
  local decoded, report = pcall(vim.json.decode, text)

  if not decoded or type(report) ~= 'table' or type(report.files) ~= 'table' then
    return nil,
      status(context, 'invalid-report', 'npm-groovy-lint returned no valid JSON report; inspect stderr and Java.')
  end

  return report.files, nil
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  local files, problem = decode_files(output, context)

  if files == nil then
    assert(problem ~= nil)

    return {
      problem,
    }
  end

  local keys, malformed, limited = sorted_string_keys(files, LIMITS.files)
  local diagnostics = {}
  local target_found = false

  for _, filename in ipairs(keys) do
    if is_target(context, filename) then
      target_found = true

      local file_malformed, file_limited = append_file(diagnostics, context, files[filename])

      malformed = malformed or file_malformed
      limited = limited or file_limited
    end
  end

  if #keys > 0 and not target_found then
    append_status(diagnostics, status(context, 'other-files', 'npm-groovy-lint returned results for another file.'))
  end

  if malformed then
    append_status(diagnostics, status(context, 'malformed-result', 'Some npm-groovy-lint results were malformed.'))
  end

  if limited then
    append_status(
      diagnostics,
      status(context, 'result-limit', 'The editor result limit was reached; run the CLI for all findings.')
    )
  end

  return diagnostics
end

---@param project_root string
---@return string?
local function resolve_executable(project_root)
  local local_executable = fs.joinpath(project_root, 'node_modules', '.bin', TOOLING.executable)

  if fn.executable(local_executable) == 1 then
    return local_executable
  end

  local executable = fn.exepath(TOOLING.executable)

  if executable ~= '' then
    return executable
  end

  return nil
end

---@param primary string
---@param cleanup_problem string?
---@return string
local function with_cleanup_problem(primary, cleanup_problem)
  if cleanup_problem == nil then
    return primary
  end

  return primary .. '; cleanup failed: ' .. cleanup_problem
end

---@param path string
---@return string? problem
local function cleanup_temporary(path)
  local problems = {}
  local unlinked, unlink_error = uv.fs_unlink(path)

  if not unlinked and uv.fs_stat(path) ~= nil then
    problems[#problems + 1] = 'unlink: ' .. tostring(unlink_error)
  end

  local directory = fs.dirname(path)

  if directory == nil then
    return 'cannot resolve private formatter directory'
  end

  local removed, remove_error = uv.fs_rmdir(directory)

  if not removed and uv.fs_stat(directory) ~= nil then
    problems[#problems + 1] = 'rmdir: ' .. tostring(remove_error)
  end

  if #problems > 0 then
    return table.concat(problems, ', ')
  end

  return nil
end

---@param filename string
---@param content string
---@return string? path
---@return string? problem
local function write_temporary(filename, content)
  local directory, directory_error = uv.fs_mkdtemp(fn.tempname() .. '-npm-groovy-lint-XXXXXX')

  if directory == nil then
    return nil, 'cannot create private formatter directory: ' .. tostring(directory_error)
  end

  local path = fs.joinpath(directory, fs.basename(filename))
  local descriptor, open_error = uv.fs_open(path, 'wx', 384)

  if descriptor == nil then
    local cleanup_problem = cleanup_temporary(path)

    return nil, with_cleanup_problem('cannot create private formatter input: ' .. tostring(open_error), cleanup_problem)
  end

  local offset = 0

  while offset < #content do
    local written, write_error = uv.fs_write(descriptor, content:sub(offset + 1), offset)

    if written == nil or written == 0 then
      local closed, close_error = uv.fs_close(descriptor)
      local primary = 'cannot write private formatter input: ' .. tostring(write_error)

      if not closed then
        primary = primary .. '; close failed: ' .. tostring(close_error)
      end

      return nil, with_cleanup_problem(primary, cleanup_temporary(path))
    end

    offset = offset + written
  end

  local closed, close_error = uv.fs_close(descriptor)

  if not closed then
    local primary = 'cannot close private formatter input: ' .. tostring(close_error)

    return nil, with_cleanup_problem(primary, cleanup_temporary(path))
  end

  return path, nil
end

---@param path string
---@return string? content
---@return string? problem
local function read_temporary(path)
  local stat, stat_error = uv.fs_stat(path)

  if stat == nil or stat.type ~= 'file' then
    return nil, 'formatter output is not a regular file: ' .. tostring(stat_error)
  end

  if stat.size > LIMITS.source_bytes then
    return nil, 'formatter output exceeded 4 MiB'
  end

  local descriptor, open_error = uv.fs_open(path, 'r', 384)

  if descriptor == nil then
    return nil, 'cannot open formatter output: ' .. tostring(open_error)
  end

  local content, read_error = uv.fs_read(descriptor, stat.size, 0)
  local closed, close_error = uv.fs_close(descriptor)

  if content == nil then
    return nil, 'cannot read formatter output: ' .. tostring(read_error)
  end

  if not closed then
    return nil, 'cannot close formatter output: ' .. tostring(close_error)
  end

  return content, nil
end

---@param executable string
---@param mode NpmGroovyLintMode
---@param project_root string
---@param temporary_path string
---@return string[]
local function transform_command(executable, mode, project_root, temporary_path)
  local command = {
    executable,
  }

  if mode == 'format' then
    command[#command + 1] = '--format'
  else
    assert(mode == 'fix')
    command[#command + 1] = '--fix'
    command[#command + 1] = '--fixrules=all'
  end

  command[#command + 1] = '--nolintafter'
  command[#command + 1] = '--output=none'
  command[#command + 1] = '--failon=none'
  command[#command + 1] = '--config=' .. project_root
  add_server_arguments(command)
  command[#command + 1] = '--'
  command[#command + 1] = temporary_path

  return command
end

---@param filename string
---@param content string
---@param mode NpmGroovyLintMode
---@return string? transformed
---@return string? problem
local function transform_content(filename, content, mode)
  local project_root = root_for_path(filename)
  local executable = resolve_executable(project_root)

  if executable == nil then
    return nil, 'npm-groovy-lint is not executable globally or in node_modules/.bin'
  end

  local temporary_path, temporary_error = write_temporary(filename, content)

  if temporary_path == nil then
    return nil, temporary_error
  end

  local command = transform_command(executable, mode, project_root, temporary_path)
  local started, job = pcall(vim.system, command, {
    cwd = project_root,
    env = {
      FORCE_COLOR = '0',
      NO_COLOR = '1',
    },
    text = true,
    timeout = runtime.transform_timeout_ms,
  })

  if not started then
    local primary = 'cannot start npm-groovy-lint: ' .. tostring(job)

    return nil, with_cleanup_problem(primary, cleanup_temporary(temporary_path))
  end

  local waited, result = pcall(job.wait, job)

  if not waited then
    local primary = 'cannot wait for npm-groovy-lint: ' .. tostring(result)

    return nil, with_cleanup_problem(primary, cleanup_temporary(temporary_path))
  end

  if result.code ~= 0 or (result.signal or 0) ~= 0 then
    local detail = result.stderr ~= '' and result.stderr or result.stdout or 'unknown failure'
    local primary = 'npm-groovy-lint failed: ' .. clean(detail)

    return nil, with_cleanup_problem(primary, cleanup_temporary(temporary_path))
  end

  local transformed, read_error = read_temporary(temporary_path)
  local cleanup_problem = cleanup_temporary(temporary_path)

  if transformed == nil then
    assert(read_error ~= nil)

    return nil, with_cleanup_problem(read_error, cleanup_problem)
  end

  if cleanup_problem ~= nil then
    return nil, 'cleanup failed: ' .. cleanup_problem
  end

  return transformed, nil
end

---@param bufnr integer
---@return string
local function buffer_content(bufnr)
  local content = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')

  if vim.bo[bufnr].endofline then
    content = content .. '\n'
  end

  return content
end

---@param bufnr integer
---@param content string
local function replace_buffer(bufnr, content)
  local endofline = content:sub(-1) == '\n'

  if endofline then
    content = content:sub(1, -2)
  end

  local lines = vim.split(content, '\n', {
    plain = true,
  })

  api.nvim_buf_call(bufnr, function()
    vim.cmd('silent! undojoin')
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end)
  vim.bo[bufnr].endofline = endofline
end

---@param bufnr? integer
---@param mode? NpmGroovyLintMode
---@return boolean changed
---@return string? problem
function M.transform_buffer(bufnr, mode)
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end

  mode = mode or 'format'

  assert(mode == 'format' or mode == 'fix')

  if not api.nvim_buf_is_valid(bufnr) or not api.nvim_buf_is_loaded(bufnr) then
    return false, 'buffer is not valid and loaded'
  end

  if vim.bo[bufnr].buftype ~= '' or not vim.bo[bufnr].modifiable then
    return false, 'buffer is not a modifiable file buffer'
  end

  if transforming[bufnr] then
    return false, 'buffer transformation is already running'
  end

  local filename = api.nvim_buf_get_name(bufnr)
  local content = buffer_content(bufnr)

  if filename == '' then
    return false, 'buffer must have a filename'
  end

  if #content > LIMITS.source_bytes then
    return false, 'buffer exceeded the 4 MiB transformation limit'
  end

  transforming[bufnr] = true

  local transformed_ok, transformed, problem = pcall(transform_content, filename, content, mode)

  transforming[bufnr] = nil

  if not transformed_ok then
    return false, 'npm-groovy-lint transformation crashed: ' .. tostring(transformed)
  end

  if transformed == nil then
    return false, problem
  end

  if not api.nvim_buf_is_valid(bufnr) or api.nvim_buf_get_name(bufnr) ~= filename then
    return false, 'buffer changed identity during transformation'
  end

  if transformed == content then
    return false, nil
  end

  replace_buffer(bufnr, transformed)

  return true, nil
end

---@param options NpmGroovyLintSetupOptions
local function configure_runtime(options)
  local keys, malformed, limited = sorted_string_keys(options, 16)

  assert(not malformed)
  assert(not limited)

  for _, name in ipairs(keys) do
    assert(SETUP_FIELDS[name] == true, 'unknown npm-groovy-lint option: ' .. name)
  end

  if options.format_on_save ~= nil then
    assert(type(options.format_on_save) == 'boolean')
    runtime.format_on_save = options.format_on_save
  end

  if options.notify ~= nil then
    assert(type(options.notify) == 'boolean')
    runtime.notify = options.notify
  end

  if options.save_mode ~= nil then
    assert(options.save_mode == 'format' or options.save_mode == 'fix')
    runtime.save_mode = options.save_mode
  end

  if options.server_host ~= nil then
    assert(type(options.server_host) == 'string')
    runtime.server_host = options.server_host
  end

  if options.server_port ~= nil then
    assert(type(options.server_port) == 'number')
    assert(integer(options.server_port) == options.server_port)
    runtime.server_port = options.server_port
  end

  if options.transform_timeout_ms ~= nil then
    assert(type(options.transform_timeout_ms) == 'number')
    assert(integer(options.transform_timeout_ms) == options.transform_timeout_ms)
    runtime.transform_timeout_ms = options.transform_timeout_ms
  end

  if options.use_server ~= nil then
    assert(type(options.use_server) == 'boolean')
    runtime.use_server = options.use_server
  end

  assert(runtime.server_host:match('^http://127%.0%.0%.1$') ~= nil)
  assert(runtime.server_port >= 1024)
  assert(runtime.server_port <= 65535)
  assert(runtime.transform_timeout_ms >= 1000)
  assert(runtime.transform_timeout_ms <= 300000)
end

---@param mode NpmGroovyLintMode
---@param success_message string
local function run_user_transform(mode, success_message)
  local changed, problem = M.transform_buffer(0, mode)

  if problem ~= nil then
    vim.notify(problem, vim.log.levels.ERROR, {
      title = 'npm-groovy-lint',
    })
  elseif changed and runtime.notify then
    vim.notify(success_message, vim.log.levels.INFO, {
      title = 'npm-groovy-lint',
    })
  end
end

local function create_commands()
  api.nvim_create_user_command('GroovyLintFormat', function()
    run_user_transform('format', 'Groovy buffer formatted')
  end, {
    desc = 'Format the current Groovy buffer',
    force = true,
  })
  api.nvim_create_user_command('GroovyLintFix', function()
    run_user_transform('fix', 'Groovy buffer fixes applied')
  end, {
    desc = 'Apply all available npm-groovy-lint fixes',
    force = true,
  })
end

---@param group integer
local function create_format_autocmd(group)
  if not runtime.format_on_save then
    return
  end

  api.nvim_create_autocmd('BufWritePre', {
    group = group,
    pattern = FILE_PATTERNS,
    desc = 'Format Groovy safely before writing',
    callback = function(event)
      local _, problem = M.transform_buffer(event.buf, runtime.save_mode)

      if problem ~= nil and runtime.notify then
        vim.notify(problem, vim.log.levels.ERROR, {
          title = 'npm-groovy-lint',
        })
      end
    end,
  })
end

---@param options? NpmGroovyLintSetupOptions
function M.setup(options)
  options = options or {}

  assert(type(options) == 'table')
  configure_runtime(options)

  local group = api.nvim_create_augroup('npm_groovy_lint_format', {
    clear = true,
  })

  create_format_autocmd(group)
  create_commands()
end

M.args = lint_arguments
M.append_fname = false
M.automatic = true
M.cwd = root
M.env = {
  FORCE_COLOR = '0',
  NO_COLOR = '1',
}
M.exit_codes = {
  0,
}
M.ignore_exitcode = false
M.parser = parse
M.root_markers = ROOT_MARKERS
M.stdin = false
M.stream = 'stdout'
M.timeout = TOOLING.timeout_ms

return M
