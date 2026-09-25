-- #################################################################
-- /qompassai/tests/startup.lua
-- Qompass AI Startup
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
-- Run from this bundle: nvim --headless -i NONE -u tests/startup.lua
local bundle = vim.fn.getcwd()
vim.opt.runtimepath:prepend(bundle)
for _, name in ipairs({
    'bsp',
    'dap',
    'formatters',
    'linters',
    'mappings',
    'plugin',
    'scip',
    'types',
    'utils',
}) do
    package.preload[name] = function()
        return {}
    end
end
package.preload['config.init'] = function()
    return {
        config = function()
            require('config.nav').nav_config()
        end,
    }
end
package.preload['config.nav.fzf'] = function()
    return {
        setup = function()
            return true
        end,
    }
end
for _, name in ipairs({
    'ripgrep',
    'searxng',
}) do
    package.preload['config.nav.' .. name] = function()
        return {}
    end
end
local ok, err = pcall(dofile, bundle .. '/init.lua')
if not ok then
    print(err)
    vim.cmd('cquit 1')
end
vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
        vim.schedule(function()
            local success, reason = pcall(function()
                local root = vim.fn.tempname() .. ' startup dir'
                vim.fn.mkdir(root, 'p')
                vim.fn.writefile({ 'startup contents' }, root .. '/test.txt')
                require('config.nav.nt').open(root)
                assert(vim.wait(3000, function()
                    return vim.bo.filetype == 'directory'
                end, 10))
                assert(vim.b.nvim_dir ~= nil)
                vim.fn.search('^test.txt$', 'w')
                require('config.nav.nt').open_selected()
                assert(vim.api.nvim_get_current_line() == 'startup contents')
                vim.fn.delete(root, 'rf')
                print(
                    'PASS: root init options, native navigation and normal VimEnter startup; external modules stubbed'
                )
            end)
            if not success then
                print(reason)
                vim.cmd('cquit 1')
            end
            vim.cmd('qa!')
        end)
    end,
})
