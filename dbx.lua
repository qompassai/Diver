-- /qompassai/Diver/dbx.lua
-- Qompass AI Diver Database Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ------------------------------------------------------
return {
    {
        name = {
            'MySQL Local',
        },
        kind = 'sqlite',
        lsp = true,
        url = {
            'mysql://root:password@localhost:3306/',
        },
    },
    {
        name = {
            'MySQL Production',
        },
        url = 'mysql://user:password@production-server:3306/database',
    },
    {
        name = {
            'SQLite Main',
        },
        url = 'sqlite:~/databases/main.sqlite',
    },
    {
        name = {
            'QMail',
        },
        url = {
            'sqlite:./db/development.sqlite3',
        },
    },
    {
        name = {
            'Project DB',
        },
        url = 'sqlite:./db/development.sqlite3',
    },
    {
        name = {
            'Zotero',
        },
        url = {
            'sqlite:~/.local/share/zotero/zotero.sqlite',
        },
    },
    {
        name = 'PostgreSQL Local',
        url = 'postgresql://postgres:password@localhost:5432/postgres',
    },
    {
        name = 'PostgreSQL Production',
        url = 'postgresql://user:password@production-server:5432/database',
    },
}
