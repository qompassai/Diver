-- tests/lua/huggingface.lua
-- Balanced suite for the huggingface module: exactly half adversarial
-- and half validation (7 checks each, 14 total). Run from the repo root
-- with the FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/huggingface.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $HF_REPORT (default /tmp/hf_report.txt).
-- No real network: parsers run against fixture JSON; a fake `hf` and a
-- fake `fake-python3` on PATH log every argv they receive to
-- $HF_FAKE_LOG; bogus binary names exercise the unavailable paths;
-- upload-confirm Cancel must spawn nothing (asserted via the log).
local report_path = os.getenv('HF_REPORT') or '/tmp/hf_report.txt'
local log_lines = {}
local function emit(line)
    log_lines[#log_lines + 1] = line
end
local adv_passed, adv_failed = 0, 0
local val_passed, val_failed = 0, 0
local function adv_check(cond, msg)
    if cond then
        adv_passed = adv_passed + 1
        emit('ok [A] - ' .. msg)
    else
        adv_failed = adv_failed + 1
        emit('NOT OK [A] - ' .. msg)
    end
end
local function val_check(cond, msg)
    if cond then
        val_passed = val_passed + 1
        emit('ok [V] - ' .. msg)
    else
        val_failed = val_failed + 1
        emit('NOT OK [V] - ' .. msg)
    end
end

local huggingface = require('ai.huggingface')
local hfapi = require('ai.huggingface.api')

local fakebin = '/tmp/hf_test_bin'
local fake_log = '/tmp/hf_fake.log'
local saved_path = vim.env.PATH or ''
local saved_token = vim.env.HF_TOKEN

local function write_file(path, text)
    local f = io.open(path, 'w')
    assert(f ~= nil, 'cannot write ' .. path)
    f:write(text)
    f:close()
end
os.execute('mkdir -p ' .. fakebin)
-- Fake `hf`: answers `version`, logs every other argv to $HF_FAKE_LOG.
write_file(
    fakebin .. '/hf',
    [=[
#!/bin/sh
log="${HF_FAKE_LOG:-/tmp/hf_fake.log}"
if [ "$1" = "version" ]; then
  echo "hf 1.8.0"
  exit 0
fi
printf '%s\n' "$*" >> "$log"
exit 0
]=]
)
-- Fake python3 under a name that cannot shadow the real one: answers the
-- verified `python -m huggingface_hub.cli.hf` entry point and pip probes.
write_file(
    fakebin .. '/fake-python3',
    [=[
#!/bin/sh
log="${HF_FAKE_LOG:-/tmp/hf_fake.log}"
if [ "$1" = "-m" ]; then
  case "$2" in
    huggingface_hub.cli.hf)
      if [ "$3" = "--help" ]; then exit 0; fi
      shift 2
      printf '%s\n' "$*" >> "$log"
      exit 0
      ;;
    pip)
      if [ "$3" = "show" ] && [ "$4" = "hf-xet" ]; then
        exit "${HF_FAKE_PIP_SHOW_XET:-0}"
      fi
      if [ "$3" = "show" ] && [ "$4" = "huggingface_hub" ]; then
        echo "Name: huggingface_hub"
        echo "Version: 1.7.0"
        exit 0
      fi
      exit 1
      ;;
  esac
fi
exit 1
]=]
)
os.execute('chmod +x ' .. fakebin .. '/hf ' .. fakebin .. '/fake-python3')
vim.env.PATH = fakebin .. ':' .. saved_path
vim.env.HF_FAKE_LOG = fake_log

local function clear_log()
    os.remove(fake_log)
end
local function read_log()
    local f = io.open(fake_log, 'r')
    if f == nil then
        return ''
    end
    local text = f:read('*a') or ''
    f:close()
    return text
end

local function close_floats()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative ~= nil and cfg.relative ~= '' then
            vim.api.nvim_win_close(win, true)
        end
    end
end

-- Fixture: one real /api/models hit (google-bert/bert-base-uncased).
local MODELS_FIXTURE = '[{"_id":"621ffdc036468d709f174338","id":"google-bert/bert-base-uncased",'
    .. '"likes":3379,"trendingScore":13,"private":false,"downloads":42711978,'
    .. '"tags":["transformers","pytorch","bert","fill-mask","en","license:apache-2.0"],'
    .. '"pipeline_tag":"fill-mask","library_name":"transformers","modelId":"google-bert/bert-base-uncased"}]'

-- Fixture: one real /api/models/{id} detail record (shape verified live).
local MODEL_DETAIL_FIXTURE = '{"_id":"621ffdc036468d709f174338","id":"google-bert/bert-base-uncased",'
    .. '"author":"google-bert","likes":3379,"downloads":42711978,"private":false,"gated":false,'
    .. '"sha":"86a0f93b1dfc3a8e22d63d7e38c7f9e39c8e7c2a","lastModified":"2022-03-02T23:29:04.000Z",'
    .. '"pipeline_tag":"fill-mask","tags":["transformers","pytorch","license:apache-2.0"]}'

-- Fixture: one real /api/datasets hit (rajpurkar/squad_v2).
local DATASETS_FIXTURE = '[{"_id":"621ffdd236468d709f181f9c","id":"rajpurkar/squad_v2",'
    .. '"author":"rajpurkar","disabled":false,"gated":false,"lastModified":"2024-03-04T13:55:27.000Z",'
    .. '"likes":263,"private":false,"downloads":83337,'
    .. '"description":"Dataset Card for SQuAD 2.0. Stanford Question Answering Dataset.",'
    .. '"tags":["task_categories:question-answering","language:en","license:cc-by-sa-4.0"]}]'

-- Fixture: one real /api/papers/search hit (wrapped in {paper=...}).
local PAPERS_FIXTURE = '[{"paper":{"id":"1706.03762","title":"Attention Is All You Need",'
    .. '"summary":"The dominant sequence transduction models are based on complex recurrent networks.",'
    .. '"publishedAt":"2017-06-12T17:57:34.000Z",'
    .. '"authors":[{"name":"Ashish Vaswani"},{"name":"Noam Shazeer"},{"name":"Niki Parmar"}]}}]'

-- Upload fixture: one file with a known size.
os.execute('mkdir -p /tmp/hf_up')
write_file('/tmp/hf_up/model.bin', string.rep('x', 1234))

local function test_setup(overrides)
    local base = {
        hf_bin = 'hf',
        python_bin = 'fake-python3',
    }
    if overrides ~= nil then
        for key, value in pairs(overrides) do
            base[key] = value
        end
    end
    huggingface.setup(base)
    clear_log()
end

-- Adversarial ---------------------------------------------------------
do
    -- Truncated JSON: no error, no entries.
    local entries = hfapi.parse_models('[{"id":"a/b","likes":1')
    adv_check(#entries == 0, 'parse_models on truncated JSON yields {} without error')
end

do
    -- Hub error shape ({error=...}): no error, no entries.
    local entries = hfapi.parse_models('{"error":"rate limited","message":"429 Too Many Requests"}')
    adv_check(#entries == 0, 'parse_models on a Hub error shape yields {} without error')
end

do
    -- Oversized input: rejected before parsing.
    local entries = hfapi.parse_models(string.rep('x', 300000))
    local datasets = hfapi.parse_datasets(string.rep('y', 300000))
    local detail = hfapi.parse_model_detail(string.rep('z', 300000))
    adv_check(
        #entries == 0 and #datasets == 0 and detail == nil,
        'oversized input (>256 KiB) is rejected by every parser'
    )
end

do
    -- Bogus binaries: download reports unavailable and spawns nothing.
    test_setup({ hf_bin = 'definitely-not-hf-xyz', python_bin = 'definitely-not-python3-xyz' })
    local ok, err = huggingface.download('owner/repo', nil, {})
    adv_check(
        ok == false and type(err) == 'string' and err:find('unavailable', 1, true) ~= nil and read_log() == '',
        'bogus hf_bin + bogus python_bin: download returns nil+err mentioning unavailable; nothing spawned'
    )
end

do
    -- Upload confirm Cancel: the dry-run preview opens, but nothing spawns.
    test_setup({
        select_impl = function(_items, _opts, on_choice)
            on_choice(nil)
        end,
    })
    local ok, err = huggingface.upload('/tmp/hf_up/model.bin', 'owner/repo', {})
    close_floats()
    adv_check(
        ok == false and err == 'cancelled' and read_log() == '',
        'upload with Cancel: returns (false, "cancelled") and spawns nothing (fake log empty)'
    )
end

do
    -- Malformed repo ids are rejected before any spawn.
    test_setup()
    local bad = { 'no-slash', '../evil', 'a/b/c', '', 'owner/', '/repo' }
    local all_rejected = true
    for _, repo in ipairs(bad) do
        local ok, err = huggingface.download(repo, nil, {})
        if ok ~= false or type(err) ~= 'string' or err:find('owner/name', 1, true) == nil then
            all_rejected = false
        end
    end
    adv_check(all_rejected and read_log() == '', 'six malformed repo ids rejected pre-spawn; fake log empty')
end

do
    -- HF_TOKEN is readable via hf_token() but never lands on any argv.
    test_setup()
    vim.env.HF_TOKEN = 'hf_test_secret_zzz'
    local seen = huggingface.hf_token()
    local ok, _ = huggingface.download('owner/repo', nil, {})
    local log = read_log()
    vim.env.HF_TOKEN = saved_token
    adv_check(
        seen == 'hf_test_secret_zzz'
            and ok == true
            and log:find('hf_test_secret_zzz', 1, true) == nil
            and log:find('download owner/repo', 1, true) ~= nil,
        'HF_TOKEN readable at use time; spawned argv carries no trace of it'
    )
end

-- Validation ----------------------------------------------------------
do
    -- parse_models fixture: id, likes, downloads, pipeline tag, tags.
    local entries = hfapi.parse_models(MODELS_FIXTURE)
    local entry = entries[1]
    val_check(
        #entries == 1
            and entry.id == 'google-bert/bert-base-uncased'
            and entry.likes == 3379
            and entry.downloads == 42711978
            and entry.pipeline_tag == 'fill-mask'
            and entry.tags[1] == 'transformers',
        'parse_models: bert-base-uncased, likes 3379, downloads 42711978, pipeline fill-mask'
    )
end

do
    -- parse_datasets fixture + license_of extraction.
    local entries = hfapi.parse_datasets(DATASETS_FIXTURE)
    local entry = entries[1]
    val_check(
        #entries == 1
            and entry.id == 'rajpurkar/squad_v2'
            and entry.author == 'rajpurkar'
            and entry.likes == 263
            and entry.downloads == 83337
            and (entry.description or ''):find('SQuAD', 1, true) ~= nil
            and hfapi.license_of(entry.tags) == 'cc-by-sa-4.0',
        'parse_datasets: squad_v2 fields correct; license_of extracts cc-by-sa-4.0'
    )
end

do
    -- parse_papers fixture: wrapped {paper=...} shape, author objects.
    local entries = hfapi.parse_papers(PAPERS_FIXTURE)
    local entry = entries[1]
    val_check(
        #entries == 1
            and entry.id == '1706.03762'
            and entry.title == 'Attention Is All You Need'
            and entry.authors[1] == 'Ashish Vaswani'
            and entry.authors[3] == 'Niki Parmar'
            and (entry.summary or ''):find('recurrent', 1, true) ~= nil,
        'parse_papers: unwraps {paper=...}, extracts author names and summary'
    )
end

do
    -- parse_model_detail fixture: license from tags, lastModified, sha.
    local detail = hfapi.parse_model_detail(MODEL_DETAIL_FIXTURE)
    val_check(
        detail ~= nil
            and detail.id == 'google-bert/bert-base-uncased'
            and detail.license == 'apache-2.0'
            and detail.pipeline_tag == 'fill-mask'
            and detail.last_modified == '2022-03-02T23:29:04.000Z'
            and (detail.sha or ''):sub(1, 12) == '86a0f93b1dfc'
            and detail.gated == false
            and detail.private == false,
        'parse_model_detail: license apache-2.0, lastModified, sha, gated/private flags'
    )
end

do
    -- Fake hf download: exact argv, revision flag only when given.
    test_setup()
    local ok1, _ = huggingface.download('owner/repo', 'main', {})
    local log1 = read_log()
    clear_log()
    local ok2, _ = huggingface.download('owner/repo', nil, {})
    local log2 = read_log()
    close_floats()
    val_check(
        ok1 == true
            and log1 == 'download owner/repo --revision main\n'
            and ok2 == true
            and log2 == 'download owner/repo\n',
        'download spawns the exact argv: with --revision when given, without when omitted'
    )
end

do
    -- Upload plan: exact argv + file sizes; confirmed upload spawns it.
    test_setup({
        select_impl = function(_items, _opts, on_choice)
            on_choice(1)
        end,
    })
    local plan, plan_err = huggingface.upload_plan('/tmp/hf_up/model.bin', 'owner/repo')
    local plan_ok = plan ~= nil
        and plan_err == nil
        and #plan.argv == 4
        and plan.argv[1] == 'hf'
        and plan.argv[2] == 'upload'
        and plan.argv[3] == 'owner/repo'
        and plan.argv[4] == '/tmp/hf_up/model.bin'
        and #plan.files == 1
        and plan.files[1].size == 1234
        and plan.total_bytes == 1234
    local ok, _ = huggingface.upload('/tmp/hf_up/model.bin', 'owner/repo', {})
    local log = read_log()
    close_floats()
    val_check(
        plan_ok and ok == true and log == 'upload owner/repo /tmp/hf_up/model.bin\n',
        'upload_plan: exact argv + 1234-byte file; confirmed upload spawns that argv'
    )
end

do
    -- setup() is idempotent: exactly the nine commands, config rebuilt
    -- without mutating M.default_config, defaults alphabetical.
    huggingface.setup()
    huggingface.setup()
    local commands = vim.api.nvim_get_commands({})
    local expected_commands = {
        'HfModels',
        'HfDatasets',
        'HfPapers',
        'HfDownload',
        'HfUpload',
        'HfXetStatus',
        'HfValidate',
        'HfUpdateCheck',
        'HfDocs',
    }
    local found = 0
    for _, name in ipairs(expected_commands) do
        if commands[name] ~= nil then
            found = found + 1
        end
    end
    local keys = {}
    for key, _ in pairs(huggingface.default_config) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local expected_keys = {
        'api_base',
        'confirm_upload',
        'docs_url',
        'float_height',
        'float_width',
        'hf_bin',
        'hf_xet_package',
        'page_size',
        'papers_endpoint',
        'python_bin',
        'results_max',
        'search_timeout_s',
        'timeout_ms',
    }
    local keys_match = #keys == #expected_keys and huggingface.default_config.select_impl == nil
    if keys_match then
        for index, key in ipairs(keys) do
            if key ~= expected_keys[index] then
                keys_match = false
                break
            end
        end
    end
    huggingface.setup({ page_size = 5 })
    local pristine = huggingface.default_config.page_size == 20
        and huggingface.config.page_size == 5
        and huggingface.config ~= huggingface.default_config
    huggingface.setup()
    val_check(
        found == 9 and keys_match and pristine,
        'setup idempotent: 9 Hf* commands; 13 alphabetical defaults (+nil select_impl); '
            .. 'config rebuilt, defaults pristine'
    )
end

-- Restore the world: default config, original PATH/env/token, fakes gone.
huggingface.setup()
close_floats()
vim.env.PATH = saved_path
vim.env.HF_FAKE_LOG = nil
vim.env.HF_TOKEN = saved_token
os.remove(fakebin .. '/hf')
os.remove(fakebin .. '/fake-python3')
os.execute('rmdir ' .. fakebin .. ' 2>/dev/null')
os.remove(fake_log)
os.execute('rm -rf /tmp/hf_up')

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
assert(f ~= nil, 'cannot open report path ' .. report_path)
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
