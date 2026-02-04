-- mail.lua - Consolidated mail utility with CSV functions
local M = {}
local api = vim.api
local fn = vim.fn
local notify = vim.notify
local uv = vim.uv or vim.loop
local JobQueue = {
    queue = {},
    running = false,
}
function JobQueue:start_next()
    if self.running or #self.queue == 0 then
        return
    end
    self.running = true
    local job = table.remove(self.queue, 1)
    self:run_job(job.cmd, job.args, job.callback, job.stdin)
end

function JobQueue:run_job(cmd, args, callback, stdin)
    M.message(string.format('Running %s', cmd), 'INFO')
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)
    local stdin_pipe = stdin and uv.new_pipe(false) or nil
    local stdout_data, stderr_data = {}, {}
    local handle
    handle = uv.spawn(cmd, {
        args = args,
        stdio = {
            stdin_pipe,
            stdout,
            stderr,
        },
        env = nil,
        cwd = nil,
        uid = nil,
        gid = nil,
        verbatim = nil,
        detached = nil,
        hide = nil,
    }, function(code, signal)
        if handle then
            uv.read_stop(stdout)
            uv.read_stop(stderr)
            stdout:close()
            stderr:close()
            if stdin_pipe then
                stdin_pipe:close()
            end
            handle:close()
        end
        local result = {
            code = code,
            signal = signal,
            stdout = table.concat(stdout_data),
            stderr = table.concat(stderr_data),
        }
        if code ~= 0 then
            M.message(string.format('Job failed: %s (code %d, signal %d)', cmd, code, signal), 'ERROR')
            print(result.stderr)
            self.queue = {}
        end
        if callback then
            callback(result)
        end
        self.running = false
        self:start_next()
    end)
    if not handle then
        M.message('Failed to start process: ' .. cmd, 'ERROR')
        stdout:close()
        stderr:close()
        if stdin_pipe then
            stdin_pipe:close()
        end
        self.queue = {}
        return
    end
    uv.read_start(stdout, function(err, data)
        if err then
            table.insert(stderr_data, err)
        elseif data then
            table.insert(stdout_data, data)
        end
    end)
    uv.read_start(stderr, function(err, data)
        if err then
            table.insert(stderr_data, err)
        elseif data then
            table.insert(stderr_data, data)
        end
    end)
    if stdin and stdin_pipe then
        uv.write(stdin_pipe, stdin, function()
            uv.shutdown(stdin_pipe, function()
                stdin_pipe:close()
            end)
        end)
    end
end

function JobQueue:add(cmd, args, callback, stdin)
    table.insert(self.queue, {
        cmd = cmd,
        args = args,
        callback = callback,
        stdin = stdin,
    })
    self:start_next()
end

local CSV = {}
function CSV.split(str, d)
    str = str:gsub('^' .. d, 'mail_nil' .. d)
    str = str:gsub(d .. '$', d .. 'mail_nil')
    local _, m = str:gsub(d, '')
    for _ = 1, m do
        str = str:gsub(d .. d, d .. 'mail_nil' .. d)
    end
    local result = {}
    local pattern = string.format('([^%s]+)', d)
    for token in string.gmatch(str, pattern) do
        table.insert(result, token)
    end
    return result
end

function CSV.csv_to_table(csv_content)
    local lines = {}
    local headers = {}
    for line in csv_content:gmatch('[^\r\n]+') do
        local row = CSV.split(line, ',')

        if #headers == 0 then
            headers = row
        else
            local rowData = {}
            for i, value in ipairs(row) do
                rowData[headers[i]] = value
            end
            table.insert(lines, rowData)
        end
    end

    return lines
end

function CSV.headers(csv_content)
    local headers = {}
    local firstLine = csv_content:match('[^\r\n]+')
    local row = CSV.split(firstLine, ',')

    for _, header in ipairs(row) do
        table.insert(headers, header)
    end

    return headers
end

function CSV.headers(csv_content)
    local headers = {}
    local firstLine = csv_content:match('[^\r\n]+')
    local row = CSV.split(firstLine, ',')
    for _, header in ipairs(row) do
        table.insert(headers, header)
    end
    return headers
end

function CSV.content(file_path)
    local file = io.open(file_path, 'r')
    if not file then
        M.message('Failed to open file: ' .. file_path, 'WARN')
        return nil
    end
    local content = file:read('*all')
    file:close()
    return content
end

local config = {
    csv = nil,
    subject = nil,
    attachment = nil,
    options = {},
}
function M.defaults()
    return {
        mappings = {
            attachment = '<leader>a',
            config = '<leader>c',
            preview = '<leader>p',
            send_text = '<leader>st',
            send_html = '<leader>sh',
        },
        options = {
            mail_client = {
                text = 'neomutt',
                html = 'neomutt',
            },
            auto_break_md = true,
            neomutt_config = '$HOME/.neomuttrc',
            mailx_account = nil,
            save_log = true,
            log_file = './nvmm.log',
            date_format = '%Y-%m-%d',
            pandoc_metadatas = {
                'title= ',
                'margin-top=0',
                'margin-left=0',
                'margin-right=0',
                'margin-bottom=0',
                'mainfont: sans-serif',
            },
        },
    }
end

function M.message(msg, level)
    local levels = {
        INFO = vim.log.levels.INFO,
        WARN = vim.log.levels.WARN,
        ERROR = vim.log.levels.ERROR,
    }
    notify('[Mail] ' .. msg, levels[level] or vim.log.levels.INFO)
end

function M.write_log(type, subject, message)
    if not config.options.save_log then
        return
    end
    local log_file = io.open(config.options.log_file, 'a')
    if not log_file then
        return
    end
    local timestamp = os.date(config.options.date_format)
    log_file:write(string.format('[%s] %s | %s | %s\n', timestamp, type, subject, message))
    log_file:close()
end

function M.write_to_quickfix(type, message, line_num)
    local qf_type = type == 'i' and 'I' or 'E'
    local qf_entry = {
        bufnr = api.nvim_get_current_buf(),
        lnum = line_num or 1,
        text = message,
        type = qf_type,
    }
    fn.setqflist({
        qf_entry,
    }, 'a')
end

function M.merge(input, csv_content, line)
    local csv_headers = CSV.headers(csv_content)
    local output = input
    local function replace_variables(text, header, data)
        if data then
            return text:gsub('%$' .. header, data)
        else
            text = text:gsub(' %$' .. header .. ' ', ' ')
            text = text:gsub(' %$' .. header, '')
            text = text:gsub('%$' .. header .. ' ', '')
            text = text:gsub('%$' .. header, '')
            return text
        end
    end
    for _, header in ipairs(csv_headers) do
        local value = CSV.csv_to_table(csv_content)[line][header]
        output = replace_variables(output, header, value ~= 'mail_nil' and value or nil)
    end
    return output
end

local function exit_handler(to, subject, type, n)
    return function(result)
        vim.schedule(function()
            if result.code == 0 then
                if config.options.save_log then
                    M.write_log(type, subject, to)
                end
                M.write_to_quickfix('i', 'Mail "' .. subject .. '" sent successfully to ' .. to, n)
            else
                M.write_to_quickfix('e', 'Mail not sent to ' .. to, n)
            end
        end)
    end
end

function M.send(type, subject, content, to, n)
    if to == 'nvmm_nil' then
        M.write_to_quickfix('e', 'This line doesn\'t contain an email', n)
        if config.options.save_log then
            local message = 'LINE ' .. n .. ' DOESN\'T CONTAIN EMAIL'
            M.write_log(type, subject, message)
        end
        return
    end

    local attachment = config.attachment or ''
    if attachment ~= '' and n ~= 0 and config.csv then
        attachment = M.merge(attachment, config.csv, n)
    end
    local client = type == 'text' and config.options.mail_client.text or config.options.mail_client.html
    if client == 'mailx' or client == 'mail' then
        local args = { '-s', subject }
        if attachment ~= '' then
            table.insert(args, '-a')
            table.insert(args, attachment)
        end
        if config.options.mailx_account then
            table.insert(args, 1, config.options.mailx_account)
            table.insert(args, 1, '-A')
        end
        table.insert(args, to)
        JobQueue:add(client, args, exit_handler(to, subject, type, n), content)
    elseif client == 'neomutt' then
        local args = {}
        if config.options.neomutt_config then
            table.insert(args, '-F')
            table.insert(args, config.options.neomutt_config)
        end
        local opts = {
            type == 'html' and 'set content_type=text/html' or 'set content_type=text/plain',
            'set copy=no',
        }
        table.insert(args, '-e')
        table.insert(args, table.concat(opts, '; '))
        table.insert(args, '-s')
        table.insert(args, subject)
        if attachment ~= '' then
            table.insert(args, '-a')
            table.insert(args, attachment)
        end
        table.insert(args, '--')
        table.insert(args, to)
        JobQueue:add('neomutt', args, exit_handler(to, subject, type, n), content)
    else
        M.message(string.format('Unknown mail client: %s', client), 'ERROR')
    end
end

function M.merge(input, csv_content, line)
    local csv_headers = CSV.headers(csv_content)
    local output = input
    local function replace_variables(text, header, data)
        if data then
            return text:gsub('%$' .. header, data)
        else
            text = text:gsub(' %$' .. header .. ' ', ' ')
            text = text:gsub(' %$' .. header, '')
            text = text:gsub('%$' .. header .. ' ', '')
            text = text:gsub('%$' .. header, '')
            return text
        end
    end
    for _, header in ipairs(csv_headers) do
        local value = CSV.csv_to_table(csv_content)[line][header]
        output = replace_variables(output, header, value ~= 'nvmm_nil' and value or nil)
    end
    return output
end

function M.markdown_to_html(md_path)
    local tmp_md_path = fn.tempname()
    local tmp_md_file = io.open(tmp_md_path, 'w')
    if not tmp_md_file then
        M.message('Failed to create temp file', 'ERROR')
        return nil
    end
    local line_end = config.options.auto_break_md and '  \n' or '\n'
    for line in io.lines(md_path) do
        tmp_md_file:write((line:gsub('%$', '_esc_dollar_')) .. line_end)
    end
    tmp_md_file:close()
    local meta = table.concat(config.options.pandoc_metadatas, ' --metadata ')
    local cmd = string.format('pandoc %s -s -f markdown -t html5 --metadata %s', tmp_md_path, meta)
    local output = fn.system(cmd)
    if not output or output == '' then
        M.message('Pandoc conversion failed', 'ERROR')
        return nil
    end
    return output:gsub('_esc_dollar_', '%$')
end

function M.set_config()
    vim.cmd('silent! write')
    vim.ui.input({
        prompt = '[Mail] CSV file? ',
        completion = 'file',
    }, function(input)
        if not input or input == '' then
            M.message('No CSV file entered', 'ERROR')
            return
        end
        local file = io.open(input, 'r')
        if not file then
            M.message('The file ' .. input .. ' does not exist', 'ERROR')
            return
        end
        local mime_check = io.popen('file --mime-type -b ' .. input):read('*a')
        if not mime_check:match('text/csv') then
            M.message('The file ' .. input .. ' is not a valid CSV file', 'ERROR')
            io.close(file)
            return
        end
        config.csv = file:read('*all')
        io.close(file)
        vim.ui.input({
            prompt = '[Mail] Subject? ',
        }, function(subj_input)
            config.subject = subj_input or ' '
        end)
    end)
end

function M.add_attachment()
    vim.ui.input({
        prompt = '[Mail] Attachment? ',
        completion = 'file',
    }, function(input)
        config.attachment = input or nil
    end)
end

local function direct_send(type, mail, recipients)
    vim.ui.input({ prompt = '[Mail] Subject? ' }, function(subject)
        subject = subject or ' '
        for _, recipient in ipairs(recipients) do
            M.send(type, subject, mail, recipient, 0)
        end
    end)
end
local function send_command(type)
    return function(args)
        fn.execute('write')
        local content
        if type == 'html' then
            content = M.markdown_to_html(fn.expand('%'))
            if not content then
                return
            end
        else
            local file = io.open(fn.expand('%'), 'r')
            if not file then
                M.message('Failed to read file', 'ERROR')
                return
            end
            content = file:read('*a')
            file:close()
        end
        local mails = {}
        for _, arg in ipairs(args.fargs) do
            for _, mail in ipairs(vim.split(arg, ',')) do
                table.insert(mails, mail)
            end
        end
        if #mails > 0 then
            direct_send(type, content, mails)
            return
        end
        if not config.csv then
            M.message('Run :MailConfig first', 'WARN')
            return
        end
        local csv_table = CSV.csv_to_table(config.csv)
        if not csv_table[1] or not csv_table[1]['MAIL'] then
            M.message('Can\'t find MAIL in CSV headers', 'ERROR')
            return
        end
        for n, row in ipairs(csv_table) do
            local merged_mail = M.merge(content, config.csv, n)
            local merged_subject = M.merge(config.subject, config.csv, n)
            M.send(type, merged_subject, merged_mail, row['MAIL'], n)
        end
    end
end
function M.setup(opts)
    opts = opts or {}
    config.options = vim.tbl_deep_extend('force', {}, M.defaults().options, opts.options or {})
    local mappings = vim.tbl_deep_extend('force', {}, M.defaults().mappings, opts.mappings or {})
    api.nvim_create_user_command('MailConfig', function()
        M.set_config()
        if config.csv then
            local headers = CSV.headers(config.csv)
            for _, header in ipairs(headers) do
                fn.matchadd('@variable', '%$' .. header)
            end
        end
    end, {
        desc = 'Configure mail merge with CSV file and subject',
    })
    api.nvim_create_user_command('MailAttachment', M.add_attachment, {
        desc = 'Add attachment to mail',
    })
    api.nvim_create_user_command('MailSendText', send_command('text'), {
        nargs = '*',
        desc = 'Send email as plain text',
    })
    api.nvim_create_user_command('MailSendHtml', send_command('html'), {
        nargs = '*',
        desc = 'Convert markdown to HTML and send email',
    })
    api.nvim_create_user_command('MailPreview', function()
        fn.execute('write')
        if not config.csv then
            M.message('Run :MailConfig first', 'WARN')
            return
        end
        local file = io.open(fn.expand('%'), 'r')
        if not file then
            return
        end
        local content = file:read('*all')
        file:close()
        local merged = M.merge(content, config.csv, 1)
        print(merged)
    end, {
        desc = 'Preview merged email',
    })
    vim.keymap.set('n', mappings.config, '<cmd>MailConfig<cr>', {})
    vim.keymap.set('n', mappings.preview, '<cmd>MailPreview<cr>', {})
    vim.keymap.set('n', mappings.attachment, '<cmd>MailAttachment<cr>', {})
    vim.keymap.set('n', mappings.send_text, '<cmd>MailSendText<cr>', {})
    vim.keymap.set('n', mappings.send_html, '<cmd>MailSendHtml<cr>', {})
end

return M