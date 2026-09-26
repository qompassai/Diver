-- /qompassai/Diver/lsp/snyk_ls.lua
-- Qompass AI Snyk LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'snyk-ls',
    },
    filetypes = {
        'apex',
        'apexcode',
        'c',
        'cpp',
        'cs',
        'dart',
        'dockerfile',
        'eelixir',
        'elixir',
        'groovy',
        'java',
        'kotlin',
        'objc',
        'objcpp',
        'php',
        'ruby',
        'rust',
        'scala',
        'swift',
    },
    init_options = {
        hoverVerbosity = 3,
        outputFormat = 'md',
        requiredProtocolVersion = '25',
        settings = {
            additional_environment = {
                changed = true,
                value = '',
            },
            additional_parameters = {
                changed = true,
                value = '',
            },
            ambient_canary_autonomy = {
                changed = true,
                value = '',
            },
            api_endpoint = {
                changed = true,
                value = 'https://api.snyk.io',
            },
            authentication_method = {
                changed = true,
                value = 'oauth',
            },
            auto_configure_mcp_server = {
                changed = true,
                value = '',
            },
            auto_determined_org = {
                changed = true,
                value = '',
            },
            automatic_authentication = {
                changed = true,
                value = true,
            },
            automatic_download = {
                changed = true,
                value = true,
            },
            base_branch = {
                changed = true,
                value = '',
            },
            binary_base_url = {
                changed = true,
                value = '',
            },
            cli_additional_oss_parameters = {
                changed = true,
                value = '',
            },
            cli_release_channel = {
                changed = true,
                value = '',
            },
            code_endpoint = {
                changed = true,
                value = '',
            },
            cve_ids = {
                changed = true,
                value = '',
            },
            cwe_ids = {
                changed = true,
                value = '',
            },
            enable_snyk_learn_code_actions = {
                changed = true,
                value = true,
            },
            enable_snyk_open_browser_actions = {
                changed = true,
                value = false,
            },
            enable_snyk_oss_quick_fix_code_actions = {
                changed = true,
                value = false,
            },
            format = {
                changed = true,
                value = 'md',
            },
            hover_verbosity = {
                changed = true,
                value = 3,
            },
            issue_view_ignored_issues = {
                changed = true,
                value = false,
            },
            issue_view_open_issues = {
                changed = true,
                value = true,
            },
            llm_base_url = {
                changed = true,
                value = '',
            },
            llm_model = {
                changed = true,
                value = '',
            },
            llm_provider = {
                changed = true,
                value = '',
            },
            local_branches = {
                changed = true,
                value = '',
            },
            offline = {
                changed = true,
                value = false,
            },
            org_set_by_user = {
                changed = true,
                value = false,
            },
            organization = {
                changed = true,
                value = '',
            },
            preferred_org = {
                changed = true,
                value = '',
            },
            proxy_http = {
                changed = true,
                value = '',
            },
            proxy_https = {
                changed = true,
                value = '',
            },
            proxy_insecure = {
                changed = true,
                value = false,
            },
            proxy_no_proxy = {
                changed = true,
                value = '',
            },
            publish_security_at_inception_rules = {
                changed = true,
                value = '',
            },
            reference_branch = {
                changed = true,
                value = '',
            },
            reference_folder = {
                changed = true,
                value = '',
            },
            risk_score_threshold = {
                changed = true,
                value = 0,
            },
            rule_ids = {
                changed = true,
                value = '',
            },
            sast_settings = {
                changed = true,
                value = '',
            },
            scan_automatic = {
                changed = true,
                value = true,
            },
            scan_command_config = {
                changed = true,
                value = '',
            },
            scan_net_new = {
                changed = true,
                value = '',
            },
            secure_at_inception_execution_frequency = {
                changed = true,
                value = '',
            },
            send_error_reports = {
                changed = true,
                value = true,
            },
            severity_filter_critical = {
                changed = true,
                value = true,
            },
            severity_filter_high = {
                changed = true,
                value = true,
            },
            severity_filter_low = {
                changed = true,
                value = true,
            },
            severity_filter_medium = {
                changed = true,
                value = true,
            },
            snyk_advisor_enabled = {
                changed = true,
                value = false,
            },
            snyk_code_enabled = {
                changed = true,
                value = false,
            },
            snyk_iac_enabled = {
                changed = true,
                value = true,
            },
            snyk_oss_enabled = {
                changed = true,
                value = true,
            },
            snyk_secrets_enabled = {
                changed = true,
                value = false,
            },
            trust_enabled = {
                changed = true,
                value = true,
            },
            trusted_folders = {
                changed = true,
                value = {},
            },
        },
    },
    root_markers = {
        '.git',
    },
    workspace_required = true,
}
