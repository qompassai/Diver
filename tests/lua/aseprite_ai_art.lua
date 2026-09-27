-- Headless test for games/aseprite AI-art import + prompt builder.
-- Runs under plain Lua (no Neovim): installs a minimal vim stub, then
-- exercises the pure logic. vim-dependent orchestration (jobstart,
-- ui prompts) is out of scope here and covered on Matt's machine.
--
-- Split: 12 validation checks, 12 adversarial checks.
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

-- Minimal vim stub: only what config/util need at require time, plus
-- what the pure helpers touch. Anything else fails loudly.
vim = {
    fn = {
        expand = function(s)
            return s
        end,
        executable = function(_)
            return 0
        end,
        has = function(_)
            return 0
        end,
    },
    log = { levels = { INFO = 1, WARN = 2, ERROR = 3 } },
    notify = function() end,
}

local pass_count, fail_count = 0, 0
local adversarial_pass, adversarial_fail = 0, 0
local function check(name, cond, adversarial, detail)
    if cond then
        pass_count = pass_count + 1
        if adversarial then
            adversarial_pass = adversarial_pass + 1
        end
    else
        fail_count = fail_count + 1
        if adversarial then
            adversarial_fail = adversarial_fail + 1
        end
        print('FAIL: ' .. name .. (detail and (' -- ' .. detail) or ''))
    end
end

local prompts = require('games.aseprite.prompts')
local import = require('games.aseprite.import')

-- ============ validation: prompt builder ============
local defaults = prompts.default_opts()
check('default_opts has concept field', defaults.concept == '')
check('default_opts has pose', defaults.pose:find('stance') ~= nil)
check('default_opts has style', #defaults.style > 10)

local ok_prompt, ok_err = prompts.build_prompt({
    concept = 'A clockwork owl mechanic with brass wings.',
    palette = 'brass #b08d57, slate #1c2541',
    pose = 'perched, wings half open',
    style = 'detailed 16-bit pixel art game sprite',
    background = 'solid black background',
    extra = '',
})
check('build_prompt emits prompt', ok_prompt ~= nil, false, tostring(ok_err))
check('prompt carries originality guard', ok_prompt and ok_prompt:find('Original character design') ~= nil)
check('prompt carries concept', ok_prompt and ok_prompt:find('clockwork owl') ~= nil)
check('prompt bans text/watermark', ok_prompt and ok_prompt:find('No text, no watermark') ~= nil)

check('screen_forbidden clean text -> nil', prompts.screen_forbidden('a brave knight') == nil)
local vok, verr = prompts.validate_opts({ concept = 'x' })
check('validate_opts accepts minimal', vok and verr == nil)

-- ============ validation: import helpers ============
check('valid_image_ext png', import.valid_image_ext('art.PNG'))
check('valid_image_ext webp', import.valid_image_ext('a.webp'))
check('valid_image_ext rejects lua', not import.valid_image_ext('x.lua'))
local out = import.output_path_for('/tmp/art.png')
check('output_path_for appends _sprite', out == '/tmp/art_sprite.png')
check('output differs from input', out ~= '/tmp/art.png')

-- Real PNG header: signature + IHDR len(13) + 'IHDR' + w=300 BE + h=200 BE.
local header = '\137PNG\r\n\26\n'
    .. string.pack('>I4', 13)
    .. 'IHDR'
    .. string.pack('>I4', 300)
    .. string.pack('>I4', 200)
    .. string.rep('\0', 9)
local w, h = import.parse_png_dimensions(header)
check('parse_png_dimensions 300x200', w == 300 and h == 200)

check('scale_factor 512->128', import.scale_factor(512, 512, 128) == 0.25)
check('scale_factor unknown -> 1.0', import.scale_factor(nil, nil, 128) == 1.0)
check('key_color_hex black', import.key_color_hex('black') == '#000000')
check('key_color_hex magenta', import.key_color_hex('magenta') == '#ff00ff')

local script = import.build_aseprite_script({ key_hex = '#000000', fuzz = 12 })
check('script uses pixels() API', script:find('img:pixels()', 1, true) ~= nil)
check('script carries key color', script:find('#000000', 1, true) ~= nil)
check('script has no app.alert (UI-only, fails in batch)', script:find('app.alert', 1, true) == nil, true)
check(
    'script gates RGB color mode before rgba* extractors',
    script:find('spr.colorMode == ColorMode.RGB', 1, true) ~= nil,
    true
)
check('script wraps mutations in app.transaction', script:find('app.transaction(', 1, true) ~= nil, true)

local argv = import.build_magick_argv({
    magick = 'magick',
    input = 'in.png',
    output = 'out.png',
    key_hex = '#000000',
    fuzz = 8,
    frame_size_px = 128,
    colors = 64,
})
check('magick argv is array, no shell', argv[1] == 'magick' and argv[#argv] == 'out.png')
check('magick argv has point filter', (function()
    for _, a in ipairs(argv) do
        if a == 'point' then
            return true
        end
    end
    return false
end)())

-- ============ adversarial ============
local blocked, blocked_err = prompts.build_prompt({
    concept = 'Cloud Strife from Final Fantasy with a big sword.',
})
check('blocks franchise name in concept', blocked == nil and blocked_err ~= nil, true, tostring(blocked_err))
check(
    'block message names token',
    blocked_err and blocked_err:find('final fantasy') ~= nil,
    true
)

local blocked2 = prompts.build_prompt({ concept = 'TIFA lockhart style fighter' })
check('screen is case-insensitive', blocked2 == nil, true)

local blocked3, err3 = prompts.build_prompt({
    concept = 'An original knight.',
    palette = 'sephiroth silver and black',
})
check('screens palette field too', blocked3 == nil and err3 ~= nil, true)

local long_concept = string.rep('x', 2001)
local blocked4, err4 = prompts.build_prompt({ concept = long_concept })
check('rejects oversized concept', blocked4 == nil and err4 ~= nil, true)

local blocked5 = prompts.build_prompt({ concept = '   ' })
check('rejects blank concept', blocked5 == nil, true)

local blocked6 = prompts.build_prompt('not a table')
check('rejects non-table opts', blocked6 == nil, true)

check('screen_forbidden empty -> nil', prompts.screen_forbidden('') == nil, true)
check('screen_forbidden nil -> nil', prompts.screen_forbidden(nil) == nil, true)

local bad_out, bad_err = import.output_path_for('')
check('output_path_for empty -> err', bad_out == nil and bad_err ~= nil, true)

local gw, gh = import.parse_png_dimensions('garbage-not-a-png')
check('parse_png_dimensions garbage -> nil', gw == nil and gh == nil, true)
local sw, sh = import.parse_png_dimensions('\137PNG\r\n\26\n' .. string.rep('\0', 10))
check('parse_png_dimensions truncated -> nil', sw == nil and sh == nil, true)

check('valid_image_ext evil.png.exe', not import.valid_image_ext('evil.png.exe'), true)
check('scale_factor zero -> 1.0', import.scale_factor(0, 0, 128) == 1.0, true)

print(string.format(
    '\naseprite_ai_art: %d passed, %d failed (adversarial %d/%d)',
    pass_count,
    fail_count,
    adversarial_pass,
    adversarial_pass + adversarial_fail
))
os.exit(fail_count > 0 and 1 or 0)
