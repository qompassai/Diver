return {
    "eyalk11/speech-to-text.nvim",
    lazy = false,
    config = function()
        vim.keymap.set('n', '<C-L>', ':Voice<CR>')
        vim.keymap.set('i', '<C-L>', '<C-R>=GetVoice()<CR>')
    end,
    build = ":!python -m pip install -r ./requirements.txt | :UpdateRemotePlugins"
}
