-- tests/lua/personas.lua
-- Balanced suite for the herd personas module: exactly half adversarial
-- and half validation (7 checks each, 14 total). Run from the repo root
-- with the FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/personas.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $PERSONAS_REPORT (default /tmp/personas_report.txt).
-- The suite never touches the real ~/.config/agent-ctrl dir: it builds
-- its own fixture dir under /tmp with valid and adversarial *.md files.
local report_path = os.getenv('PERSONAS_REPORT') or '/tmp/personas_report.txt'
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

local personas = require('ai.herd.personas')

local fixture_dir = '/tmp/personas_fixtures'
vim.fn.delete(fixture_dir, 'rf')
assert(vim.fn.mkdir(fixture_dir, 'p') == 1, 'cannot create fixture dir')

local function write_fixture(name, text)
    local f = io.open(fixture_dir .. '/' .. name, 'w')
    assert(f ~= nil, 'cannot write fixture ' .. name)
    f:write(text)
    f:close()
end

-- Valid fixtures (names chosen so sorting is exercised: alpha < builder < sage).
write_fixture(
    'a_alpha.md',
    table.concat({
        '---',
        'name: alpha',
        'description: Alpha discovery persona.',
        'category: discovery',
        '---',
        '',
        'You are alpha, a discovery assistant.',
        '',
    }, '\n')
)
write_fixture(
    'b_builder.md',
    table.concat({
        '---',
        'name: builder',
        'description: Builder persona for engineering tasks.',
        'category: engineering',
        'mcp-servers: [exa]',
        '---',
        '',
        'You are builder, an engineering assistant.',
        '',
    }, '\n')
)
write_fixture(
    'c_sage.md',
    table.concat({
        '---',
        'name: sage',
        'description: Sage reviewer persona.',
        'category: quality',
        '---',
        '',
        'You are sage, a code reviewer.',
        '',
    }, '\n')
)
-- Valid, with the repo's HTML license-header convention before frontmatter.
write_fixture(
    'e_licensed.md',
    table.concat({
        '<!-- license header -->',
        '<!-- more -->',
        '',
        '---',
        'name: licensed',
        'description: Licensed header persona.',
        'category: quality',
        '---',
        '',
        'Body of licensed.',
        '',
    }, '\n')
)
-- Adversarial fixtures.
write_fixture('no_front.md', 'Just a body, no frontmatter at all.\n')
write_fixture('bad_line.md', '---\nname: badline\na line with no colon\n---\n\nBody.\n')
write_fixture('no_name.md', '---\ndescription: nameless\ncategory: quality\n---\n\nBody.\n')
write_fixture('empty_body.md', '---\nname: emptybody\ndescription: x\ncategory: quality\n---\n\n   \n')
write_fixture('bad_key.md', '---\nname: badkey\nbad key!: oops\n---\n\nBody.\n')
write_fixture('huge.md', '---\nname: huge\ndescription: big\ncategory: quality\n---\n\n' .. string.rep('x', 70000))

personas.setup({ agents_dir = fixture_dir })

local EXPECTED_COMMANDS = {
    'PersonasList',
    'PersonasDocs',
    'PersonasValidate',
    'PersonasUpdateCheck',
}

local function user_commands()
    return vim.api.nvim_get_commands({})
end

local function errors_mention(errors, file, fragment)
    for _, err in ipairs(errors) do
        if err:find(file, 1, true) ~= nil and err:find(fragment, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local entries, errors = personas.load_personas(fixture_dir)

-- Validation ------------------------------------------------------------
do
    local commands = user_commands()
    local all_present = true
    for _, name in ipairs(EXPECTED_COMMANDS) do
        if commands[name] == nil then
            all_present = false
        end
    end
    local twice_ok = pcall(personas.setup, { agents_dir = fixture_dir })
        and pcall(personas.setup, { agents_dir = fixture_dir })
    local count = 0
    for _, name in ipairs(EXPECTED_COMMANDS) do
        if user_commands()[name] ~= nil then
            count = count + 1
        end
    end
    val_check(
        all_present and twice_ok and count == 4,
        'all 4 :Personas* commands registered; setup() idempotent, still exactly 4'
    )
end

do
    local explicit = true
    for key, _ in pairs(personas.default_config) do
        if personas.config[key] == nil then
            explicit = false
        end
    end
    personas.setup({ agents_dir = fixture_dir, spawn_hook_enabled = false })
    local override_ok = personas.config.spawn_hook_enabled == false and not personas.spawn_hook_enabled()
    personas.setup({ agents_dir = fixture_dir })
    local restored = personas.config.spawn_hook_enabled == true and personas.spawn_hook_enabled()
    local defaults_intact = personas.default_config.spawn_hook_enabled == true
        and personas.default_config.agents_dir == '~/.config/agent-ctrl/agents'
    val_check(
        explicit and override_ok and restored and defaults_intact,
        'config fully explicit; overrides apply, nil restores, default_config never mutated'
    )
end

do
    local names = {}
    for _, entry in ipairs(entries) do
        names[#names + 1] = entry.name
    end
    local builder
    for _, entry in ipairs(entries) do
        if entry.name == 'builder' then
            builder = entry
        end
    end
    local err_text = table.concat(errors, '\n')
    local all_bad_named = true
    for _, file in ipairs({ 'no_front.md', 'bad_line.md', 'no_name.md', 'empty_body.md', 'bad_key.md', 'huge.md' }) do
        if err_text:find(file, 1, true) == nil then
            all_bad_named = false
        end
    end
    local bodies_ok = true
    for _, entry in ipairs(entries) do
        if entry.body == '' or entry.frontmatter['name'] == nil then
            bodies_ok = false
        end
    end
    val_check(
        #entries == 4
            and #errors == 6
            and names[1] == 'alpha'
            and names[2] == 'builder'
            and names[3] == 'licensed'
            and names[4] == 'sage'
            and all_bad_named
            and bodies_ok
            and builder ~= nil
            and builder.frontmatter['category'] == 'engineering'
            and builder.frontmatter['mcp-servers'] == '[exa]'
            and builder.frontmatter['description'] == 'Builder persona for engineering tasks.',
        'load_personas: 4 valid entries (alpha/builder/licensed/sage, frontmatter exact), 6 named parse errors'
    )
end

do
    local list = personas.list_personas()
    val_check(
        #list == 4
            and list[1].name == 'alpha'
            and list[2].name == 'builder'
            and list[3].name == 'licensed'
            and list[4].name == 'sage'
            and list[1].description == 'Alpha discovery persona.',
        'list_personas: sorted summaries with one-line descriptions'
    )
end

do
    local text = personas.render_prompt('alpha')
    local again = personas.render_prompt('alpha')
    local original_select = vim.ui.select
    local picked = 'unset'
    vim.ui.select = function(items, _, on_choice)
        on_choice(items[2])
    end
    local pick_ok = pcall(personas.pick_persona, function(name)
        picked = name
    end)
    vim.ui.select = original_select
    val_check(
        text ~= nil
            and text:sub(1, 4) == '---\n'
            and text:find('name: alpha', 1, true) ~= nil
            and text:find('You are alpha, a discovery assistant.', 1, true) ~= nil
            and text == again
            and personas.render_prompt('missing') == nil
            and pick_ok
            and picked == 'alpha',
        'render_prompt: --- header + body, deterministic, nil for unknown; pick_persona picks the chosen name'
    )
end

do
    local persona_text = personas.render_prompt('sage')
    val_check(
        personas.with_persona(persona_text, 'do the thing') == persona_text .. '\n\n' .. 'do the thing'
            and personas.with_persona(persona_text, nil) == persona_text
            and personas.with_persona(persona_text, '') == persona_text
            and personas.with_persona(nil, 'do the thing') == 'do the thing'
            and personas.with_persona(nil, nil) == nil
            and personas.with_persona('  ', '  ') == nil,
        'with_persona: persona+task combined, either side alone, nil when both blank'
    )
end

-- Adversarial -----------------------------------------------------------
do
    local ok, fresh_entries, fresh_errors = pcall(personas.load_personas, '/tmp/personas_no_such_dir_xyz')
    adv_check(
        ok and #fresh_entries == 0 and #fresh_errors >= 1,
        'load_personas on a missing dir reports errors, never throws'
    )
end

adv_check(errors_mention(errors, 'no_front.md', 'delimiter'), 'missing frontmatter delimiters reported, never thrown')
adv_check(errors_mention(errors, 'bad_line.md', 'malformed'), 'frontmatter line without colon reported')
adv_check(errors_mention(errors, 'no_name.md', 'name'), "frontmatter without 'name' reported")
adv_check(errors_mention(errors, 'empty_body.md', 'body'), 'empty body reported')
adv_check(errors_mention(errors, 'huge.md', 'exceeds'), 'oversized file reported as exceeding body_bytes_max')

adv_check(
    errors_mention(errors, 'bad_key.md', 'malformed')
        and not pcall(personas.setup, 'nope')
        and not pcall(personas.setup, { agents_dir = fixture_dir, body_bytes_max = 'many' }),
    'bad frontmatter key reported; setup() rejects a non-table config and a mistyped option'
)

-- Diff check runs last: it mutates the fixture dir.
do
    personas.setup({ agents_dir = fixture_dir })
    personas.refresh()
    write_fixture('d_new.md', '---\nname: newbie\ndescription: n\ncategory: quality\n---\n\nNew.\n')
    local fresh = personas.load_personas(fixture_dir)
    local diff = personas.diff_index(fresh)
    local added_ok = #diff.added == 1 and diff.added[1] == 'newbie'
    local f = io.open(fixture_dir .. '/b_builder.md', 'a')
    assert(f ~= nil, 'cannot append to builder fixture')
    f:write('More body text to change the size.\n')
    f:close()
    local fresh2 = personas.load_personas(fixture_dir)
    local diff2 = personas.diff_index(fresh2)
    local changed_ok = #diff2.changed == 1 and diff2.changed[1] == 'builder'
    os.remove(fixture_dir .. '/a_alpha.md')
    local fresh3 = personas.load_personas(fixture_dir)
    local diff3 = personas.diff_index(fresh3)
    local removed_ok = #diff3.removed == 1 and diff3.removed[1] == 'alpha'
    val_check(
        added_ok and changed_ok and removed_ok,
        'diff_index: new file added, appended file changed, deleted file removed'
    )
end

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
assert(f ~= nil, 'cannot open report path ' .. report_path)
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
