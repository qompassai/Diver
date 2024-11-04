return {
    {
        "kndndrj/nvim-projector",
        lazy = true,
        dependencies = {
            "MunifTanjim/nui.nvim",
            "kndndrj/projector-neotest",
            "nvim-neotest/neotest",
            "nvim-telescope/telescope.nvim",
            "nvim-treesitter/nvim-treesitter",
            "neovim/nvim-lspconfig",
            "hrsh7th/nvim-cmp",
            "mfussenegger/nvim-dap",
            "folke/trouble.nvim",
            "nvim-lualine/lualine.nvim",
        },
        config = function()
            require("projector").setup( --[[optional config]])
        end,
    },
    {
        "kndndrj/nvim-dbee",
        lazy = true,
        event = "VeryLazy",
        dependencies = {
            "MunifTanjim/nui.nvim",
            "nvim-telescope/telescope.nvim",
            "dccsillag/magma-nvim",
            "lewis6991/gitsigns.nvim",
            "hrsh7th/nvim-cmp",
            "lervag/vimtex",
            "nvim-lualine/lualine.nvim",
            "mfussenegger/nvim-dap",
        },
        build = function()
            local dbee = require("dbee")
            dbee.install("go")
            local dbee_path = os.getenv("HOME") .. "/.local/share/nvim/dbee/bin/dbee"
            if vim.loop.fs_stat(dbee_path) then
                vim.loop.fs_chmod(dbee_path, 755)
            else
                print("Error: DBee binary not found!")
            end
        end,
        config = function()
            local function get_password()
                local handle = io.popen "pass show pianodb"
                if not handle then
                    return nil
                end
                local result = handle:read "*a"
                handle:close()
                return result and result:gsub("%s+", "") or nil
            end

            local function get_hf_token()
                local handle = io.popen "pass show hf"
                if not handle then
                    return nil
                end
                local result = handle:read "*a"
                handle:close()
                return result and result:gsub("%s+", "") or nil
            end

            local function download_hf_dataset_with_hf_cli(dataset_url)
                local hf_token = get_hf_token()
                if not hf_token then
                    print("Error: Failed to retrieve Hugging Face token from pass")
                    return
                end
                local local_dir = "/home/phaedrus/Forge/HF/Data"
                local command = string.format(
                    'huggingface-cli download "%s" --repo-type dataset --local-dir "%s" --token "%s"',
                    dataset_url,
                    local_dir,
                    hf_token
                )
                local result = os.execute(command)
                if result ~= 0 then
                    print("Error: Failed to download the dataset from Hugging Face")
                else
                    print("Dataset downloaded successfully to " .. local_dir)
                end
            end

            require("dbee").setup {
                sources = {
                    require("dbee.sources").MemorySource:new {
                        --Comment out from line 53-61 if you are not following Qompass naming convention
                        {
                            name = "pianodb",
                            type = "postgresql",
                            user = "phaedrus",
                            password = get_password(),
                            host = "localhost",
                            port = 5432,
                            database = "pianodb",
                        },
                        --DuckDB
                        {
                            name = "qompassdb",
                            type = "duckdb",
                            database = os.getenv("HOME") .. "/.db/qompass.db",
                            supports_http = true,
                            hf_token = get_hf_token(),
                        },
                        -- Uncomment and configure additional databases as needed:
                        -- {
                        --   name = "my_mysql_db",
                        --   type = "mysql",
                        --   user = "mysql_user",
                        --   password = "mysql_password",
                        --   host = "localhost",
                        --   port = 3306,
                        --   database = "my_database",
                        -- },
                        -- {
                        --   name = "my_mongo_db",
                        --   type = "mongodb",
                        --   user = "mongo_user",
                        --   password = "mongo_password",
                        --   host = "localhost",
                        --   port = 27017,
                        --   database = "my_mongo_database",
                        -- },
                        -- {
                        --   name = "my_redis_db",
                        --   type = "redis",
                        --   host = "localhost",
                        --   port = 6379,
                        -- },
                        -- {
                        --   name = "my_sqlite_db",
                        --   type = "sqlite",
                        --   database = "/path/to/your/sqlite.db", -- SQLite does not use host/port
                        -- },
                        -- {
                        --   name = "my_mssql_db",
                        --   type = "mssql",
                        --   user = "mssql_user",
                        --   password = "mssql_password",
                        --   host = "localhost",
                        --   port = 1433,
                        --   database = "my_mssql_database",
                        -- },
                        -- {
                        --   name = "my_oracle_db",
                        --   type = "oracle",
                        --   user = "oracle_user",
                        --   password = "oracle_password",
                        --   host = "localhost",
                        --   port = 1521,
                        --   database = "my_oracle_database",
                        -- },
                        -- {
                        --   name = "my_cassandra_db",
                        --   type = "cassandra",
                        --   host = "localhost",
                        --   port = 9042,
                        --   keyspace = "my_keyspace",
                        -- },
                    },
                },
            }
            -- Run DuckDB query after dataset download
            local function run_duckdb_query(database_path, output_path)
                local duckdb = require("dbee.sources").MemorySource:new {
                    name = "qompassdb",
                    type = "duckdb",
                    database = database_path,
                }

                -- SQL query to create a table and load the dataset
                local sql_query = string.format(
                    [[CREATE TABLE IF NOT EXISTS bone_fracture_data AS SELECT * FROM read_parquet('%s');]],
                    output_path
                )

                local success, err = pcall(function()
                    duckdb:query(sql_query) -- Run your query
                end)
                if not success then
                    print("Error: Failed to execute the SQL query in DuckDB - " .. (err or "unknown error"))
                end
            end

            -- Create custom command for downloading the dataset
            vim.api.nvim_create_user_command(
                "DownloadHF",
                function()
                    local dataset_url = "Francesco/bone-fracture-7fylg"
                    local output_path = "/home/phaedrus/Forge/HF/Data/bone_fracture_data.parquet"
                    download_hf_dataset_with_hf_cli(dataset_url)
                    run_duckdb_query(os.getenv("HOME") .. "/.db/qompass.db", output_path)
                end,
                { desc = "Download Hugging Face dataset and load into DuckDB" }
            )
        end,
    },
}
