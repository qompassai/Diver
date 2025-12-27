-- ~/.config/nvim/lua/config/container.lua
local M = {}
function M.docker_opts()
    return {
        ui = {
            select = {
                enabled = true,
                backend = 'fzf', -- can be "telescope", "fzf", or "nui"
                float_opts = {
                    relative = 'editor',
                    width = 0.8,
                    height = 0.8,
                    border = 'rounded',
                },
            },
        },
        docker = {
            cmd = 'docker',
            compose_cmd = 'docker-compose',
        },
    }
end

function M.schema_opts()
    return {
        extra = {
            {
                fileMatch = {
                    'docker-compose*.yml',
                    'docker-compose*.yaml',
                    'compose.yml',
                    'compose.yaml',
                },
                url = 'https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json',
            },
            {
                fileMatch = { 'Dockerfile*', 'containerfile*' },
                url = 'https://raw.githubusercontent.com/moby/buildkit/master/frontend/dockerfile/schema/dockerfile.json',
            },
        },
    }
end

function M.setup_filetype_detection()
    vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
        pattern = {
            '*docker-compose*.yml',
            '*docker-compose*.yaml',
            'compose.yml',
            'compose.yaml',
        },
        callback = function()
            vim.bo.filetype = 'docker-compose.yml'
        end,
    })
    vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
        pattern = { '*Dockerfile*', '*containerfile*', '*Containerfile*' },
        callback = function()
            vim.bo.filetype = 'dockerfile'
        end,
    })
end

function M.setup_all(opts)
    opts = opts or {}
    require('nvim-docker').setup(M.docker_opts())
    M.setup_filetype_detection()
    return M.docker_opts()
end

return M
