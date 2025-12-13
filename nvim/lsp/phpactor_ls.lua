--[[
/qompassai/diver/lsp/phpactor.lua
Qompass AI Diver Phpactor LSP Config
Copyright (C) 2025 Qompass AI, All rights reserved
---------------------------------------------------------------
References: https://phpactor.readthedocs.io/en/master/reference/configuration.html
]]
vim.lsp.config['phpactor_ls'] = {
    cmd = {
        'phpactor',
        'language-server',
    },
    filetypes = {
        'php',
        'phps',
        'blade',
    },
    root_markers = {
        'composer.json',
        '.git',
    },
    settings = {
        phpactor = {
            behat = {
                enabled = true,
                config_path = '%project_root%/behat.yml',
                symfony = {
                    di_xml_path = nil,
                },
            },
            blackfire = {
                enabled = false,
            },
            class_to_file = {
                brute_force_conversion = true,
                project_root = '%project_root%',
            },
            code_transform = {
                class_new = { variants = {} },
                indentation = ' ',
                import_globals = true,
                refactor = {
                    generate_accessor = {
                        prefix = '',
                        upper_case_first = false,
                    },
                    generate_mutator = {
                        prefix = 'set',
                        upper_case_first = true,
                        fluent = false,
                    },
                    object_fill = {
                        hint = true,
                        named_parameters = true,
                    },
                },
                template_paths = {
                    '%project_config%/templates',
                    '%config%/templates',
                },
            },
            composer = {
                autoload_deregister = true,
                autoloader_path = '%project_root%/vendor/autoload.php',
                class_maps_only = true,
                enable = true,
            },
            completion = {
                dedupe = true,
                dedupe_match_fqn = true,
                label_formatter = 'helpful',
                limit = nil,
            },
            completion_worse = {
                debug = false,
                experimantal = false,
                name_completion_priority = 'proximity',
                snippets = true,
                completor = {
                    attribute = {
                        enabled = true,
                    },
                    class_like = {
                        enabled = true,
                    },
                    class_member = {
                        enabled = true,
                    },
                    class = {
                        limit = 100,
                        enabled = true,
                    },
                    constructor = {
                        enabled = true,
                    },
                    declared_class = {
                        enabled = true,
                    },
                    declared_constant = {
                        enabled = true,
                    },
                    declared_function = {
                        enabled = true,
                    },
                    docblock = {
                        enabled = true,
                    },
                    doctrine_annotation = {
                        enabled = true,
                    },
                    expression_name_search = {
                        enabled = true,
                    },
                    imported_names = {
                        enabled = true,
                    },
                    keyword = {
                        enabled = true,
                    },
                    local_variable = {
                        enabled = true,
                    },
                    named_parameter = {
                        enabled = true,
                    },
                    scf_class = {
                        enabled = true,
                    },
                    subscript = { enabled = true },
                    type = { enabled = true },
                    use = { enabled = true },
                    worse_parameter = { enabled = true },
                    constant = { enabled = false },
                    symfony = { enabled = true },
                },
            },
            console = {
                decorated = nil,
                verbosity = 32,
            },
            core = {
                min_memory_limit = 1610612736,
            },
            console_dumper_default = 'indented',
            xdebug_disable = true,
            diagnostics = {
                diagnosticsOnOpen = true,
                diagnosticsOnUpdate = true,
                diagnosticsOnSave = true,
            },
            file_path_resolver = {
                app_name = 'phpactor',
                application_root = nil,
                enable_cache = true,
                enable_logging = true,
                project_root = '%project_root%',
            },

            indexer = {
                buffer_time = 500,
                enabled_watchers = { 'inotify', 'watchman', 'find', 'php' },
                exclude_patterns = {
                    '/vendor/**/Tests/**/*',
                    '/vendor/**/tests/**/*',
                    '/vendor/composer/**/*',
                },
                follow_symlinks = false,
                implementation_finder = { deep = true },
                include_patterns = { '/**/*.php', '/**/*.phar' },
                index_path = '%cache%/index/%project_id%',
                poll_time = 5000,
                project_root = '%project_root%',
                reference_finder = { deep = true },
                search_include_patterns = {},
                stub_paths = {},
                supported_extensions = { 'php', 'phar' },
            },
            language_server_code_transform = {
                import_name = { report_non_existing_names = true },
            },
            language_server_completion = {
                trim_leading_dollar = false,
            },
            language_server_configuration = {
                auto_config = true,
            },
            language_server = {
                catch_errors = true,
                diagnostic_exclude_paths = {},
                diagnostic_ignore_codes = {},
                diagnostic_outsource = true,
                diagnostic_outsource_timeout = 5,
                diagnostic_providers = nil,
                diagnostic_sleep_time = 1000,
                diagnostics_on_open = true,
                diagnostics_on_save = true,
                diagnostics_on_update = true,
                enable_workspace = true,
                file_event_globs = { '**/*.php' },
                file_events = true,
                method_alias_map = {},
                phpactor_bin = nil,
                profile = false,
                self_destruct_timeout = 2500,
                session_parameters = {},
                shutdown_grace_period = 200,
                trace = false,
            },
            language_server_highlight = {
                enabled = true,
            },
            language_server_indexer = {
                reindex_timeout = 300,
                workspace_symbol_search_limit = 250,
            },
            language_server_php_cs_fixer = {
                bin = '%project_root%/vendor/bin/php-cs-fixer',
                config = nil,
                enabled = false,
                env = { XDEBUG_MODE = 'off', PHP_CS_FIXER_IGNORE_ENV = true },
                show_diagnostics = true,
            },
            language_server_phpstan = {
                bin = '%project_root%/vendor/bin/phpstan',
                config = nil,
                enabled = false,
                level = nil,
                mem_limit = nil,
                tmp_file_disabled = false,
            },
            language_server_psalm = {
                bin = 'psalm --language-server',
                config = '$XDG_CONFIG_HOME/nvim/lsp/psalm.lua',
                enabled = true,
                error_level = nil,
                show_info = true,
                threads = 1,
                timeout = 15,
                use_cache = true,
            },
            language_server_reference_finder = {
                reference_timeout = 60,
                soft_timeout = 10,
            },
            language_server_worse_reflection = {
                diagnostics = { enable = true },
                inlay_hints = {
                    enable = false,
                    params = true,
                    types = false,
                },
                workspace_index = { update_interval = 100 },
            },
            logging = {
                enabled = false,
                fingers_crossed = false,
                formatter = nil,
                level = 'warning',
                path = 'application.log',
            },
            logger = { name = 'logger' },
            object_renderer = {
                template_paths = {
                    markdown = { '%project_config%/templates/markdown', '%config%/templates/markdown' },
                },
            },
            php = {
                version = '8.4',
            },
            php_code_sniffer = {
                args = {},
                bin = '%project_root%/vendor/bin/phpcs',
                cwd = nil,
                enabled = false,
                env = { XDEBUG_MODE = 'off' },
                show_diagnostics = true,
            },
            phpunit = {
                enabled = false,
            },
            prophecy = {
                enabled = false,
            },
            rpc = {
                replay_path = '%cache%/replay.json',
                store_replay = false,
            },
            source_code_filesystem = {
                project_root = '%project_root%',
            },
            symfony = {
                enabled = false,
                xml_path = '%project_root%/var/cache/dev/App_KernelDevDebugContainer.xml',
                public_services_only = false,
            },
            worse_reflection = {
                cache_dir = '%cache%/worse-reflection',
                cache_lifetime = 1,
                diagnostics = { undefined_variable = { suggestion_levenshtein_disatance = 4 } },
                enable_cache = true,
                enable_context_location = true,
                stub_dir = '%application_root%/vendor/jetbrains/phpstorm-stubs',
            },
        },
    },
}
