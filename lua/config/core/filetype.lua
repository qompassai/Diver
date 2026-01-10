-- ~/qompassai/Diver/filetype.lua
-- Qompass AI FileType Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.filetype.add({
    extension = {
        bri = 'brioche',
        brioche = 'brioche',
        comp = 'glsl',
        cr = 'crystal',
        cypher = 'cypher',
        frag = 'glsl',
        geom = 'glsl',
        hbs = 'html.handlebars',
        handlebars = 'html.handlebars',
        rst = 'rst',
        schelp = 'scdoc',
        svh = 'systemverilog',
        tesc = 'glsl',
        tese = 'glsl',
        tsx = 'typescript.tsx',
        v = 'verilog',
        verilog = 'verilog',
        vh = 'verilog',
    },
    filename = {
        ['project.bri'] = 'brioche',
        brioche = 'brioche',
        Crystal = 'crystal',
    },
    pattern = {
        ['.*/.*%.als'] = 'alloy',
        ['.*%.crystal'] = 'crystal',
        ['^.*/gitconfig.*$'] = 'gitconfig',
        ['^.*/gitignore.*$'] = 'gitignore',
        ['^.*/gitcommit.*$'] = 'gitcommit',
        ['*.gts'] = 'typescript.glimmer',
        ['*.gjs'] = 'javascript.glimmer',
    },
})