-- /qompassai/Diver/lua/utils/media/csound.lua
-- Qompass AI Diver Media CSound Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local WARN = vim.log.levels.WARN
local template = [[
<CsoundSynthesizer>
<CsOptions>
-odac              ; or -o output.wav for render-to-file
</CsOptions>
<CsInstruments>
sr = 48000
ksmps = 32
nchnls = 2
0dbfs = 1

instr 1
  a1 oscili 0.1, p4, 1    ; simple sine tone, amp 0.1, freq = p4
  outs a1, a1
endin
</CsInstruments>
<CsScore>
f 1 0 16384 10 1          ; sine wave table

; p4 is frequency
i 1 0 10 440              ; 10 seconds of 440 Hz
e
</CsScore>
</CsoundSynthesizer>
]]
function M.write_basic_csd(path)
    path = path or vim.fn.expand('%:p:h') .. '/example.csd'
    local fd = assert(io.open(path, 'w'))
    fd:write(template)
    fd:close()
    print('Wrote Csound file: ' .. path)
    vim.cmd('edit ' .. path)
end

function M.get_manual_dir()
    if vim.g.csound_manual == nil then
        return 'http://csound.github.io/docs/manual'
    else
        return vim.fn.resolve(vim.fn.expand(vim.g.csound_manual))
    end
end

local os_name = vim.uv.os_uname().sysname
function M.open_manual()
    local manual_dir = M.get_manual_dir()
    local opcode = vim.fn.expand('<cword>')
    local manual_page = string.format('%s/%s.html', manual_dir, opcode)

    if os_name == 'Linux' then
        vim.fn.jobstart({
            'xdg-open',
            manual_page,
        }, {
            detach = true,
        })
    elseif os_name == 'Darwin' or os_name == 'OSX' or os_name == 'Haiku' then
        vim.fn.jobstart({
            'open',
            manual_page,
        }, {
            detach = true,
        })
    elseif os_name == 'Windows_NT' or os_name == 'Windows' or os_name == 'Mingw' then
        vim.fn.jobstart({
            'start',
            manual_page,
        }, {
            detach = true,
        })
    else
        vim.notify('Cannot detect OS. Set g:os to one of "Linux", "OSX", "Windows", "Mingw", "Haiku".', WARN)
    end
end

function M.open_example()
    if vim.g.csound_manual == nil then
        vim.notify('g:csound_manual is not set; point it to the HTML csound manual directory', WARN)
        return
    end
    local opcode = vim.fn.expand('<cword>')
    local examplecsd = string.format('%s/examples/%s.csd', vim.fn.resolve(vim.fn.expand(vim.g.csound_manual)), opcode)
    if vim.fn.filereadable(examplecsd) == 1 then
        vim.cmd.tabnew()
        vim.cmd(('silent view %s'):format(vim.fn.fnameescape(examplecsd)))
    else
        vim.notify(examplecsd .. ' does not exist', WARN)
    end
end

if vim.g.csound_enable_manual_keys == nil then
    vim.g.csound_enable_manual_keys = 1
end
if vim.g.csound_enable_manual_keys == 1 then
    vim.keymap.set('n', '<F1>', M.open_manual, {
        desc = 'Open csound manual page',
    })
    vim.keymap.set('n', '<F2>', M.open_example, {
        desc = 'Open csound example CSD',
    })
end

return M