-- ~/.config/nvim/lua/mappings/langmap.lua
-- Native filetype tasks; explicit argv, saved files, bounded jobs/output/deadlines.
-- SPDX-License-Identifier: Apache-2.0
-- <LocalLeader>t: a actions, b build, c check, o output, r run, s status, t test, x cancel.
-- A profile owns its filetype's tools. No unrelated-language menu entries or plugins.
-- The existing run-once review remains the default. is_trusted(root) may delegate
-- to your workspace policy; only literal true bypasses that review.
-- Cancellation kills the direct child, not an arbitrary descendant process tree.
-- Profiles and task keys are alphabetical; setup has no automatic task execution.

local M = {}
local core = require('mappings._core')
local api = vim.api
local fn = vim.fn
local uv = vim.uv

local ARGV_MAX = 64
local ARG_BYTES_MAX = 8192
local JOBS_MAX = 4
local OUTPUT_BYTES_MAX = 1024 * 1024
local OUTPUT_CHUNKS_MAX = 4096
local TIMEOUT_MS = 120000
local TIMEOUT_MS_MAX = 600000

---@class LanguageTask
---@field argv string[]
---@field label string
---@field project? boolean
---@field timeout_ms? integer

---@class LanguageProfile
---@field markers string[]
---@field tasks table<string, LanguageTask>

---@class LanguageMappingsOptions
---@field is_trusted? fun(root: string): boolean
---@field prefix? string
---@field profiles? table<string, LanguageProfile|false>

---@class LanguageInvocation
---@field argv string[]
---@field bufnr integer
---@field cwd string
---@field file string
---@field filetype string
---@field label string
---@field real_file string
---@field tick integer
---@field timeout_ms integer

---@class LanguageJob
---@field bytes integer
---@field chunks string[]
---@field invocation LanguageInvocation
---@field process? vim.SystemObj
---@field stopped boolean
---@field truncated boolean
---@field timer? uv.uv_timer_t

---@param label string
---@param argv string[]
---@param project? boolean
---@return LanguageTask
local function task(label, argv, project)
  return { argv = argv, label = label, project = project }
end

---@type table<string, LanguageProfile>
local PROFILES = {
  ada = {
    markers = {},
    tasks = {
      c = task('Check Ada file', {
        'gcc',
        '-c',
        '-gnatc',
        '{file}',
      }),
    },
  },
  aiken = {
    markers = {
      'aiken.toml',
    },
    tasks = {
      b = task('Build Aiken project', {
        'aiken',
        'build',
      }, true),
      c = task('Check Aiken project', {
        'aiken',
        'check',
      }, true),
    },
  },
  bash = {
    markers = {},
    tasks = {
      c = task('Check Bash syntax', {
        'bash',
        '-n',
        '--',
        '{file}',
      }),
      r = task('Run Bash file', {
        'bash',
        '--',
        '{file}',
      }),
    },
  },
  c = {
    markers = {
      'CMakeLists.txt',
    },
    tasks = {
      b = task('Build CMake project', {
        'cmake',
        '--build',
        '{root}/build',
      }, true),
      t = task('Test CMake project', {
        'ctest',
        '--test-dir',
        '{root}/build',
      }, true),
    },
  },
  clojure = {
    markers = {
      'deps.edn',
    },
    tasks = {
      r = task('Run Clojure file', {
        'clojure',
        '-M',
        '{file}',
      }, true),
    },
  },
  cmake = {
    markers = {
      'CMakeLists.txt',
    },
    tasks = {
      b = task('Build CMake project', {
        'cmake',
        '--build',
        '{root}/build',
      }, true),
      t = task('Test CMake project', {
        'ctest',
        '--test-dir',
        '{root}/build',
      }, true),
    },
  },
  crystal = {
    markers = { 'shard.yml' },
    tasks = {
      b = task('Build Crystal shards', {
        'shards',
        'build',
      }, true),
      r = task('Run Crystal file', {
        'crystal',
        'run',
        '{file}',
      }),
      t = task('Test Crystal project', {
        'crystal',
        'spec',
      }, true),
    },
  },
  elixir = {
    markers = { 'mix.exs' },
    tasks = {
      b = task('Build Elixir project', { 'mix', 'compile' }, true),
      r = task('Run Elixir file', { 'elixir', '{file}' }),
      t = task('Test Elixir project', { 'mix', 'test' }, true),
    },
  },
  erlang = {
    markers = { 'rebar.config' },
    tasks = {
      b = task('Build Erlang project', { 'rebar3', 'compile' }, true),
      t = task('Test Erlang project', { 'rebar3', 'eunit' }, true),
    },
  },
  fennel = {
    markers = {},
    tasks = {
      r = task('Run Fennel file', {
        'fennel',
        '{file}',
      }),
    },
  },
  fish = {
    markers = {},
    tasks = {
      c = task('Check Fish syntax', {
        'fish',
        '--no-execute',
        '{file}',
      }),
      r = task('Run Fish file', { 'fish', '{file}' }),
    },
  },
  fortran = {
    markers = {},
    tasks = { c = task('Check Fortran syntax', { 'gfortran', '-fsyntax-only', '{file}' }) },
  },
  gleam = {
    markers = { 'gleam.toml' },
    tasks = {
      b = task('Build Gleam project', {
        'gleam',
        'build',
      }, true),
      c = task('Check Gleam project', { 'gleam', 'check' }, true),
      r = task('Run Gleam project', { 'gleam', 'run' }, true),
      t = task('Test Gleam project', { 'gleam', 'test' }, true),
    },
  },
  go = {
    markers = { 'go.mod', 'go.work' },
    tasks = {
      b = task('Build Go packages', { 'go', 'build', './...' }, true),
      c = task('Check Go packages', { 'go', 'vet', './...' }, true),
      r = task('Run Go package in root', { 'go', 'run', '.' }, true),
      t = task('Test Go packages', { 'go', 'test', './...' }, true),
    },
  },
  haskell = {
    markers = { 'cabal.project' },
    tasks = {
      b = task('Build Cabal project', { 'cabal', 'build' }, true),
      r = task('Run Haskell file', { 'runghc', '{file}' }),
      t = task('Test Cabal project', { 'cabal', 'test' }, true),
    },
  },
  janet = {
    markers = {},
    tasks = {
      r = task('Run Janet file', {
        'janet',
        '{file}',
      }),
    },
  },
  java = {
    markers = {
      'build.gradle',
      'build.gradle.kts',
    },
    tasks = {
      b = task('Build Gradle project', { 'gradle', 'build' }, true),
      c = task('Check Gradle project', { 'gradle', 'check' }, true),
      t = task('Test Gradle project', { 'gradle', 'test' }, true),
    },
  },
  javascript = {
    markers = { 'package.json' },
    tasks = {
      b = task('Build npm project', {
        'npm',
        'run',
        'build',
      }, true),
      c = task('Check JavaScript syntax', {
        'node',
        '--check',
        '{file}',
      }),
      r = task('Run JavaScript file', {
        'node',
        '{file}',
      }),
      t = task('Test npm project', {
        'npm',
        'test',
      }, true),
    },
  },
  julia = {
    markers = { 'Project.toml' },
    tasks = { r = task('Run Julia file', { 'julia', '--startup-file=no', '{file}' }) },
  },
  just = {
    markers = { 'Justfile', 'justfile' },
    tasks = { c = task('List Just recipes', { 'just', '--list' }, true) },
  },
  kotlin = {
    markers = { 'build.gradle', 'build.gradle.kts' },
    tasks = {
      b = task('Build Gradle project', {
        'gradle',
        'build',
      }, true),
      c = task('Check Gradle project', {
        'gradle',
        'check',
      }, true),
      t = task('Test Gradle project', {
        'gradle',
        'test',
      }, true),
    },
  },
  lean = {
    markers = {
      'lakefile.lean',
      'lakefile.toml',
    },
    tasks = {
      b = task('Build Lean project', {
        'lake',
        'build',
      }, true),
    },
  },
  lua = {
    markers = {},
    tasks = {
      r = task('Run standalone LuaJIT file', {
        'luajit',
        '{file}',
      }),
    },
  },
  mojo = {
    markers = { 'mojoproject.toml', 'pixi.toml' },
    tasks = {
      b = task('Build Mojo file', {
        'mojo',
        'build',
        '{file}',
      }),
      r = task('Run Mojo file', {
        'mojo',
        'run',
        '{file}',
      }),
    },
  },
  nix = {
    markers = {},
    tasks = {
      c = task('Parse Nix file', {
        'nix-instantiate',
        '--parse',
        '{file}',
      }),
    },
  },
  ocaml = {
    markers = { 'dune-project' },
    tasks = {
      b = task('Build Dune project', {
        'dune',
        'build',
      }, true),
      t = task('Test Dune project', {
        'dune',
        'runtest',
      }, true),
    },
  },
  odin = {
    markers = {},
    tasks = {
      b = task('Build Odin package directory', {
        'odin',
        'build',
        '.',
      }),
      c = task('Check Odin package directory', {
        'odin',
        'check',
        '.',
      }),
      r = task('Run Odin package directory', { 'odin', 'run', '.' }),
      t = task('Test Odin package directory', { 'odin', 'test', '.' }),
    },
  },
  perl = {
    markers = {},
    tasks = {
      c = task('Check Perl file (BEGIN blocks execute)', { 'perl', '-c', '{file}' }),
      r = task('Run Perl file', { 'perl', '{file}' }),
    },
  },
  php = {
    markers = {},
    tasks = {
      c = task('Check PHP syntax', { 'php', '-l', '{file}' }),
      r = task('Run PHP file', {
        'php',
        '{file}',
      }),
    },
  },
  python = {
    markers = {
      'pyproject.toml',
      'pytest.ini',
      'setup.cfg',
    },
    tasks = {
      r = task('Run Python file', {
        'python',
        '{file}',
      }),
      t = task('Test Python project', {
        'python',
        '-m',
        'pytest',
      }, true),
    },
  },
  racket = {
    markers = {},
    tasks = {
      r = task('Run Racket file', {
        'racket',
        '{file}',
      }),
      t = task('Test Racket file', {
        'raco',
        'test',
        '{file}',
      }),
    },
  },
  rego = {
    markers = {},
    tasks = {
      c = task('Check Rego file', { 'opa', 'check', '{file}' }),
      t = task('Test Rego directory', { 'opa', 'test', '.' }),
    },
  },
  ruby = {
    markers = {},
    tasks = {
      c = task('Check Ruby syntax', {
        'ruby',
        '-c',
        '{file}',
      }),
      r = task('Run Ruby file', { 'ruby', '{file}' }),
    },
  },
  rust = {
    markers = { 'Cargo.toml' },
    tasks = {
      b = task('Build Cargo project', { 'cargo', 'build' }, true),
      c = task('Check Cargo project', { 'cargo', 'check' }, true),
      r = task('Run Cargo project', { 'cargo', 'run' }, true),
      t = task('Test Cargo project', { 'cargo', 'test' }, true),
    },
  },
  scala = {
    markers = { 'build.sbt' },
    tasks = {
      b = task('Build sbt project', { 'sbt', 'compile' }, true),
      t = task('Test sbt project', { 'sbt', 'test' }, true),
    },
  },
  sh = {
    markers = {},
    tasks = {
      c = task('Check POSIX shell syntax', { 'sh', '-n', '{file}' }),
      r = task('Run POSIX shell file', { 'sh', '{file}' }),
    },
  },
  swift = {
    markers = { 'Package.swift' },
    tasks = {
      b = task('Build Swift package', {
        'swift',
        'build',
      }, true),
      r = task('Run Swift package', {
        'swift',
        'run',
      }, true),
      t = task('Test Swift package', {
        'swift',
        'test',
      }, true),
    },
  },
  tex = {
    markers = {},
    tasks = {
      b = task('Build TeX without shell escape', {
        'latexmk',
        '-pdf',
        '-interaction=nonstopmode',
        '-halt-on-error',
        '-no-shell-escape',
        '{file}',
      }),
    },
  },
  typescript = {
    markers = {
      'package.json',
    },
    tasks = {
      b = task('Build npm project', {
        'npm',
        'run',
        'build',
      }, true),
      t = task('Test npm project', { 'npm', 'test' }, true),
    },
  },
  zig = {
    markers = { 'build.zig' },
    tasks = {
      b = task('Build Zig project', {
        'zig',
        'build',
      }, true),
      r = task('Run standalone Zig file', {
        'zig',
        'run',
        '{file}',
      }),
      t = task('Test standalone Zig file', {
        'zig',
        'test',
        '{file}',
      }),
    },
  },
}

---@type table<string, string>
local ALIASES = {
  astro = 'typescript',
  cpp = 'c',
  cuda = 'c',
  javascriptreact = 'typescript',
  objc = 'c',
  objcpp = 'c',
  ocamlinterface = 'ocaml',
  plaintex = 'tex',
  svelte = 'typescript',
  typescriptreact = 'typescript',
  vue = 'typescript',
}

local COMMAND_TASKS = {
  soql = {
    c = {
      command = 'SfQueryLint',
      label = 'Check SOQL query',
    },
    r = { command = 'SfSoqlRun', label = 'Run SOQL query' },
  },
  sosl = {
    c = { command = 'SfQueryLint', label = 'Check SOSL query' },
    r = { command = 'SfSoslRun', label = 'Run SOSL query' },
  },
}

---@type table<string, LanguageProfile>
local profiles = {}
---@type table<integer, LanguageJob>
local jobs = {}
---@type table<integer, integer>
local pending = {}
---@type LanguageMappingsOptions
local options = {}
---@type string[]
local last_output = { 'No language task has completed yet.' }
local generation = 0
local group = 0
local prefix = ''

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = 'Language mappings' })
end

---@param bufnr integer
---@return boolean
local function usable(bufnr)
  return api.nvim_buf_is_valid(bufnr)
    and api.nvim_buf_is_loaded(bufnr)
    and vim.b[bufnr].nvim_dir == nil
    and vim.bo[bufnr].buftype == ''
    and vim.bo[bufnr].filetype ~= ''
end

---@param keys string
---@return string
local function keycodes(keys)
  local expanded = keys:gsub('<LocalLeader>', function()
    return vim.g.maplocalleader or '\\'
  end)
  expanded = expanded:gsub('<Leader>', function()
    return vim.g.mapleader or '\\'
  end)
  return api.nvim_replace_termcodes(expanded, true, true, true)
end

local function clear_maps(bufnr)
  core.clear('langmap', bufnr)
end

---@param lines string[]
local function show_lines(lines)
  local bufnr = api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = 'wipe'
  vim.bo[bufnr].swapfile = false
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
  vim.cmd.split()
  api.nvim_win_set_buf(0, bufnr)
end

---@param bufnr? integer
function M.status(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not usable(bufnr) then
    return
  end
  local filetype = vim.bo[bufnr].filetype
  local lines = { 'Filetype: ' .. filetype, 'Prefix: ' .. vim.fn.keytrans(prefix) }
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    lines[#lines + 1] = 'Attached server: ' .. client.name
  end
  local profile = profiles[filetype]
  if profile then
    for _, key in ipairs(vim.tbl_keys(profile.tasks)) do
      lines[#lines + 1] = key .. ': ' .. profile.tasks[key].label
    end
  else
    lines[#lines + 1] = 'No default task profile; add options.profiles.'
  end
  table.sort(lines)
  show_lines(lines)
end

function M.output()
  show_lines(last_output)
end

---@param invocation LanguageInvocation
---@return boolean
local function unchanged(invocation)
  local bufnr = invocation.bufnr
  return usable(bufnr)
    and api.nvim_get_current_buf() == bufnr
    and api.nvim_buf_get_changedtick(bufnr) == invocation.tick
    and api.nvim_buf_get_name(bufnr) == invocation.file
    and vim.bo[bufnr].filetype == invocation.filetype
    and uv.fs_realpath(invocation.file) == invocation.real_file
    and uv.fs_realpath(invocation.cwd) == invocation.cwd
    and not vim.bo[bufnr].modified
end

---@param job LanguageJob
local function close_timer(job)
  local timer = job.timer
  job.timer = nil
  if timer and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

---@param process vim.SystemObj
---@param signal_number integer
local function signal_process(process, signal_number)
  local ok, err = pcall(process.kill, process, signal_number)
  if not ok then
    vim.schedule(function()
      notify('Could not signal task process: ' .. tostring(err), vim.log.levels.WARN)
    end)
  end
end

---@param job LanguageJob
local function stop_job(job)
  if job.stopped then
    return
  end
  job.stopped = true
  close_timer(job)
  local process = job.process
  if process then
    signal_process(process, 15)
    job.timer = vim.defer_fn(function()
      job.timer = nil
      if jobs[job.invocation.bufnr] == job then
        signal_process(process, 9)
      end
    end, 1000)
  end
end

---@param bufnr? integer
function M.cancel(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  pending[bufnr] = nil
  local job = jobs[bufnr]
  if job then
    stop_job(job)
  end
end

---@param job LanguageJob
---@param data string
local function collect(job, data)
  local available = OUTPUT_BYTES_MAX - job.bytes
  if available > 0 and #data > 0 and #job.chunks < OUTPUT_CHUNKS_MAX then
    local chunk = data:sub(1, available)
    job.chunks[#job.chunks + 1] = chunk
    job.bytes = job.bytes + #chunk
  end
  if (#data > available or #job.chunks >= OUTPUT_CHUNKS_MAX) and not job.truncated then
    job.truncated = true
    vim.schedule(function()
      if jobs[job.invocation.bufnr] == job then
        stop_job(job)
      end
    end)
  end
end

---@param job LanguageJob
---@param result vim.SystemCompleted
local function finish(job, result)
  local bufnr = job.invocation.bufnr
  if jobs[bufnr] ~= job then
    return
  end
  jobs[bufnr] = nil
  close_timer(job)
  local summary = ('%s: exit %d, signal %d'):format(job.invocation.label, result.code, result.signal)
  local output = table.concat(job.chunks):gsub('%z', '?')
  last_output = { summary, 'cwd: ' .. job.invocation.cwd, '' }
  local lines = vim.split(output, '\n', { plain = true })
  for index = 1, math.min(#lines, 8192) do
    last_output[#last_output + 1] = lines[index]
  end
  if #lines > 8192 then
    last_output[#last_output + 1] = '[Output line limit reached.]'
  end
  if job.truncated then
    last_output[#last_output + 1] = '[Output limit reached; task cancelled.]'
  elseif job.stopped then
    last_output[#last_output + 1] = '[Task cancelled.]'
  end
  if api.nvim_buf_is_valid(bufnr) then
    local level = result.code == 0 and vim.log.levels.INFO or vim.log.levels.WARN
    notify(summary .. '; use ' .. vim.fn.keytrans(prefix) .. 'o for output.', level)
  end
end

---@param invocation LanguageInvocation
local function launch(invocation)
  local bufnr = invocation.bufnr
  if not unchanged(invocation) then
    notify('Buffer changed during selection; invoke the action again.', vim.log.levels.WARN)
    return
  end
  if jobs[bufnr] or vim.tbl_count(jobs) >= JOBS_MAX then
    notify('Task limit reached; cancel or wait for an active task.', vim.log.levels.WARN)
    return
  end
  ---@type LanguageJob
  local job = {
    bytes = 0,
    chunks = {},
    invocation = invocation,
    stopped = false,
    truncated = false,
  }
  jobs[bufnr] = job
  local function on_output(err, data)
    if err then
      collect(job, tostring(err) .. '\n')
    end
    if data then
      collect(job, data)
    end
  end
  local ok, process = pcall(vim.system, invocation.argv, {
    cwd = invocation.cwd,
    env = { NO_COLOR = '1', PAGER = 'cat' },
    stderr = on_output,
    stdout = on_output,
    text = true,
    timeout = invocation.timeout_ms,
  }, function(result)
    vim.schedule(function()
      finish(job, result)
    end)
  end)
  if not ok then
    jobs[bufnr] = nil
    notify('Cannot start task: ' .. tostring(process), vim.log.levels.ERROR)
    return
  end
  job.process = process
  -- vim.system's async timeout sends TERM; enforce a hard upper bound as well.
  job.timer = vim.defer_fn(function()
    job.timer = nil
    if jobs[bufnr] == job then
      signal_process(process, 9)
    end
  end, invocation.timeout_ms + 1000)
end

---@param executable string
---@param cwd string
---@return string
local function resolve_executable(executable, cwd)
  if not executable:find('[/\\]') then
    local resolved = fn.exepath(executable)
    return resolved ~= '' and fn.fnamemodify(resolved, ':p') or ''
  end
  local absolute = executable:sub(1, 1) == '/' or executable:sub(1, 1) == '\\' or executable:match('^%a:[/\\]') ~= nil
  if not absolute then
    executable = vim.fs.joinpath(cwd, executable)
  end
  return executable
end

---@param bufnr integer
---@param selected LanguageTask
---@param profile LanguageProfile
---@return LanguageInvocation?
local function prepare(bufnr, selected, profile)
  if not usable(bufnr) or vim.bo[bufnr].modified then
    notify('Save the source buffer before running a task.', vim.log.levels.WARN)
    return nil
  end
  local filetype = vim.bo[bufnr].filetype
  if type(filetype) ~= 'string' or filetype == '' then
    notify('A nonempty buffer filetype is required.', vim.log.levels.WARN)
    return nil
  end
  local file = api.nvim_buf_get_name(bufnr)
  local real_file = uv.fs_realpath(file)
  if type(real_file) ~= 'string' or real_file == '' or fn.filereadable(real_file) ~= 1 then
    notify('A saved, readable file is required.', vim.log.levels.WARN)
    return nil
  end
  local root = #profile.markers > 0 and vim.fs.root(real_file, profile.markers) or nil
  if selected.project and not root then
    notify('Project marker missing: ' .. table.concat(profile.markers, ', '))
    return nil
  end
  local directory = root or vim.fs.dirname(real_file)
  if type(directory) ~= 'string' or directory == '' then
    notify('Cannot determine the task directory.', vim.log.levels.WARN)
    return nil
  end
  local cwd = uv.fs_realpath(directory)
  if type(cwd) ~= 'string' or cwd == '' then
    notify('Task directory no longer exists.', vim.log.levels.WARN)
    return nil
  end
  local argv = {} ---@type string[]
  for _, argument in ipairs(selected.argv) do
    local expanded = argument:gsub('{([a-z_]+)}', function(token)
      if token == 'file' then
        return real_file
      end
      if token == 'root' then
        return cwd
      end
      return '{' .. token .. '}'
    end)
    if #expanded > ARG_BYTES_MAX or expanded:find('%z') then
      notify('Invalid or oversized task argument.', vim.log.levels.ERROR)
      return nil
    end
    argv[#argv + 1] = expanded
  end
  local executable = resolve_executable(argv[1], cwd)
  if executable == '' or fn.executable(executable) ~= 1 then
    notify('Executable unavailable: ' .. argv[1], vim.log.levels.WARN)
    return nil
  end
  argv[1] = executable
  ---@type LanguageInvocation
  local invocation = {
    argv = argv,
    bufnr = bufnr,
    cwd = cwd,
    file = file,
    filetype = filetype,
    label = selected.label,
    real_file = real_file,
    tick = api.nvim_buf_get_changedtick(bufnr),
    timeout_ms = selected.timeout_ms or TIMEOUT_MS,
  }
  return invocation
end

---@param invocation LanguageInvocation
local function authorize(invocation)
  local bufnr = invocation.bufnr
  generation = generation + 1
  local ticket = generation
  pending[bufnr] = ticket
  local policy = options.is_trusted
  if policy then
    local ok, trusted = pcall(policy, invocation.cwd)
    if not ok then
      pending[bufnr] = nil
      notify('Workspace policy failed: ' .. tostring(trusted), vim.log.levels.ERROR)
      return
    end
    if ok and trusted == true then
      pending[bufnr] = nil
      launch(invocation)
      return
    end
  end
  local prompt = invocation.cwd .. '\n' .. vim.inspect(invocation.argv)
  vim.ui.select({ 'Cancel', 'Run once' }, { prompt = prompt }, function(choice)
    if pending[bufnr] ~= ticket then
      return
    end
    pending[bufnr] = nil
    if choice == 'Run once' then
      launch(invocation)
    end
  end)
end

---@param selected LanguageTask
---@return boolean
local function available_task(selected)
  local executable = selected.argv[1]
  -- Relative executables are resolved against the project at invocation time.
  return executable:find('[/\\]') ~= nil or fn.executable(executable) == 1
end

---@param key string Action suffix: b, c, r or t.
---@param bufnr? integer
function M.run(key, bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not usable(bufnr) then
    return
  end
  local profile = profiles[vim.bo[bufnr].filetype]
  local selected = profile and profile.tasks[key]
  local commands = COMMAND_TASKS[vim.bo[bufnr].filetype]
  local command = commands and commands[key]
  if command and fn.exists(':' .. command.command) == 2 then
    core.command(command.command)()
    return
  end
  if not profile or not selected then
    notify('This filetype has no task for key: ' .. key)
    return
  end
  local invocation = prepare(bufnr, selected, profile)
  if invocation then
    authorize(invocation)
  end
end

---@param bufnr? integer
function M.actions(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not usable(bufnr) then
    return
  end
  local profile = profiles[vim.bo[bufnr].filetype]
  local commands = COMMAND_TASKS[vim.bo[bufnr].filetype]
  if commands then
    local items = {}
    for key, item in pairs(commands) do
      if fn.exists(':' .. item.command) == 2 then
        items[#items + 1] = {
          label = item.label,
          run = function()
            M.run(key, bufnr)
          end,
        }
      end
    end
    core.select(bufnr, items, 'Query actions: ' .. vim.bo[bufnr].filetype)
    return
  end
  if not profile or vim.tbl_isempty(profile.tasks) then
    notify('No task profile for this filetype; configure options.profiles.')
    return
  end
  local keys = {}
  for key, selected in pairs(profile.tasks) do
    if available_task(selected) then
      keys[#keys + 1] = key
    end
  end
  if #keys == 0 then
    notify('No configured task executable is available for this filetype.')
    return
  end
  table.sort(keys, function(lhs, rhs)
    return profile.tasks[lhs].label < profile.tasks[rhs].label
  end)
  local tick = api.nvim_buf_get_changedtick(bufnr)
  local filetype = vim.bo[bufnr].filetype
  generation = generation + 1
  local ticket = generation
  pending[bufnr] = ticket
  vim.ui.select(keys, {
    prompt = 'Language actions: ' .. filetype,
    format_item = function(key)
      return profile.tasks[key].label
    end,
  }, function(key)
    if pending[bufnr] ~= ticket then
      return
    end
    pending[bufnr] = nil
    if
      key
      and usable(bufnr)
      and api.nvim_get_current_buf() == bufnr
      and vim.bo[bufnr].filetype == filetype
      and api.nvim_buf_get_changedtick(bufnr) == tick
    then
      M.run(key, bufnr)
    end
  end)
end

---@param bufnr integer
function M.attach(bufnr)
  clear_maps(bufnr)
  if not usable(bufnr) then
    return
  end
  local filetype = vim.bo[bufnr].filetype
  local profile = profiles[filetype]
  local commands = COMMAND_TASKS[filetype]
  if not profile and not commands then
    return
  end
  ---@type table<string, { callback: fun(), label: string }>
  local mappings = {
    a = {
      callback = function()
        M.actions(bufnr)
      end,
      label = 'Actions',
    },
    o = { callback = M.output, label = 'Output' },
    s = {
      callback = function()
        M.status(bufnr)
      end,
      label = 'Status',
    },
    x = {
      callback = function()
        M.cancel(bufnr)
      end,
      label = 'Cancel',
    },
  }
  if profile then
    for key, selected in pairs(profile.tasks) do
      if available_task(selected) then
        mappings[key] = {
          callback = function()
            M.run(key, bufnr)
          end,
          label = selected.label,
        }
      end
    end
  end
  for key, item in pairs(commands or {}) do
    if fn.exists(':' .. item.command) == 2 then
      mappings[key] = {
        callback = function()
          M.run(key, bufnr)
        end,
        label = item.label,
      }
    end
  end
  local keys = vim.tbl_keys(mappings)
  table.sort(keys)
  local definitions = {}
  for _, key in ipairs(keys) do
    local mapping = mappings[key]
    definitions[#definitions + 1] = {
      lhs = prefix .. key,
      rhs = mapping.callback,
      desc = mapping.label,
    }
  end
  core.install('langmap', bufnr, definitions)
end

-- Refresh loaded buffers after tools or task profiles change.
function M.refresh()
  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    M.attach(bufnr)
  end
end

---@param profile LanguageProfile
local function validate_profile(profile)
  assert(type(profile) == 'table', 'profile must be a table')
  assert(type(profile.markers) == 'table' and vim.islist(profile.markers), 'profile.markers must be a list')
  assert(#profile.markers <= 32, 'too many project markers')
  assert(type(profile.tasks) == 'table', 'profile.tasks must be a table')
  for _, marker in ipairs(profile.markers) do
    assert(type(marker) == 'string' and marker ~= '', 'invalid project marker')
  end
  for key, selected in pairs(profile.tasks) do
    assert(key == 'b' or key == 'c' or key == 'r' or key == 't', 'invalid task key')
    assert(type(selected.label) == 'string' and selected.label ~= '', 'missing task label')
    assert(type(selected.argv) == 'table' and vim.islist(selected.argv), 'task.argv must be a list')
    assert(#selected.argv > 0 and #selected.argv <= ARGV_MAX, 'invalid argv size')
    for _, argument in ipairs(selected.argv) do
      assert(type(argument) == 'string', 'argv entries must be strings')
      assert(#argument <= ARG_BYTES_MAX and not argument:find('%z'), 'invalid argument')
    end
    assert(selected.argv[1] ~= '', 'missing executable')
    local timeout = selected.timeout_ms or TIMEOUT_MS
    assert(type(timeout) == 'number', 'timeout_ms must be numeric')
    assert(timeout % 1 == 0 and timeout >= 1 and timeout <= TIMEOUT_MS_MAX, 'invalid timeout')
  end
end

function M.teardown()
  core.teardown('langmap')
  if group ~= 0 then
    api.nvim_del_augroup_by_id(group)
    group = 0
  end
  pending = {}
  for _, job in pairs(jobs) do
    job.stopped = true
    close_timer(job)
    if job.process then
      signal_process(job.process, 9)
    end
  end
  jobs = {}
end

---@param opts? LanguageMappingsOptions
function M.setup(opts)
  local configured = vim.deepcopy(opts or {})
  local updated = vim.deepcopy(PROFILES)
  for alias, target in pairs(ALIASES) do
    updated[alias] = vim.deepcopy(PROFILES[target])
  end
  for filetype, profile in pairs(configured.profiles or {}) do
    if profile == false then
      updated[filetype] = nil
    else
      updated[filetype] = vim.deepcopy(profile)
    end
  end
  assert(vim.tbl_count(updated) <= 256, 'too many filetype profiles')
  for _, profile in pairs(updated) do
    validate_profile(profile)
  end
  local next_prefix = configured.prefix or '<LocalLeader>t'
  assert(type(next_prefix) == 'string' and next_prefix ~= '', 'invalid prefix')
  assert(#next_prefix <= 64, 'prefix too long')
  assert(not configured.is_trusted or type(configured.is_trusted) == 'function')
  M.teardown()
  options = configured
  profiles = updated
  prefix = keycodes(next_prefix)
  group = api.nvim_create_augroup('LanguageMappings', { clear = true })
  api.nvim_create_autocmd({ 'BufEnter', 'FileType' }, {
    callback = function(event)
      if event.event == 'FileType' then
        M.cancel(event.buf)
      end
      M.attach(event.buf)
    end,
    desc = 'Install language task mappings without replacing existing keys',
    group = group,
  })
  api.nvim_create_autocmd('BufWipeout', {
    callback = function(event)
      M.cancel(event.buf)
      clear_maps(event.buf)
    end,
    group = group,
  })
  api.nvim_create_autocmd('VimLeavePre', {
    callback = M.teardown,
    group = group,
  })
  M.refresh()
end

M.setup_langmap = M.setup
M.setup_langmappings = M.setup

return M
