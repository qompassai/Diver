-- /qompassai/Diver/lsp/apex_ls.lua
-- Qompass AI Diver Apex LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@source https://developer.salesforce.com/docs/platform/sfvscode-extensions/guide/apex-language-server.html
local uv = vim.uv
local function exists(p)
  local expanded = vim.fn.expand(p)
  return expanded ~= '' and uv.fs_stat(expanded) ~= nil
end
local function resolve_java(config)
  if config.apex_java_home and config.apex_java_home ~= '' then
    return config.apex_java_home .. '/bin/java'
  end
  if vim.env.JAVA_HOME and vim.env.JAVA_HOME ~= '' then
    return vim.env.JAVA_HOME .. '/bin/java'
  end
  return vim.fn.exepath('java') ~= '' and vim.fn.exepath('java') or 'java'
end
local function apex_cmd(dispatchers, config)
  local apex_settings = (config.settings and config.settings.apex) or {}
  local jvm = apex_settings.jvm or {}
  local java = resolve_java(config)
  local jar = config.apex_jar_path
  if not exists(jar) then
    vim.schedule(function()
      vim.notify('Apex LSP jar not found: ' .. tostring(jar), vim.log.levels.ERROR, {
        title = 'apex_ls',
      })
    end)
    return
  end
  if java ~= 'java' and not exists(java) then
    vim.schedule(function()
      vim.notify('Java executable not found: ' .. tostring(java), vim.log.levels.ERROR, {
        title = 'apex_ls',
      })
    end)
    return
  end
  local cmd = {
    java,
    '-cp',
    jar,
    string.format('-Ddebug.internal.errors=%s', tostring(jvm.debugInternalErrors ~= false)),
    string.format('-Ddebug.semantic.errors=%s', tostring(jvm.debugSemanticErrors or false)),
    string.format('-Ddebug.completion.statistics=%s', tostring(jvm.completionStatistics or false)),
    string.format('-Dlwc.typegeneration.disabled=%s', tostring(jvm.disableLwcTypeGeneration ~= false)),
  }
  if jvm.maxHeap or config.apex_jvm_max_heap then
    table.insert(cmd, '-Xmx' .. (jvm.maxHeap or config.apex_jvm_max_heap))
  end

  table.insert(cmd, 'apex.jorje.lsp.ApexLanguageServerLauncher')
  return vim.lsp.rpc.start(cmd, dispatchers)
end
local function setup_apex_format_on_save()
  local group = vim.api.nvim_create_augroup('apex-external-format', { clear = true })
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = { '*.cls', '*.trigger', '*.apex' },
    callback = function(args)
      local buf = args.buf
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      if vim.bo[buf].buftype ~= '' or vim.bo[buf].filetype ~= 'apex' then
        return
      end
      local file = vim.api.nvim_buf_get_name(buf)
      if file == '' or vim.fn.executable('apexfmt') ~= 1 then
        return
      end
      local stderr = {}
      vim.fn.jobstart({
        'apexfmt',
        file,
      }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stderr = function(_, data)
          if not data then
            return
          end
          for _, line in ipairs(data) do
            if line and line ~= '' then
              stderr[#stderr + 1] = line
            end
          end
        end,
        on_exit = function(_, code)
          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then
              return
            end

            if code == 0 then
              if vim.api.nvim_buf_is_loaded(buf) then
                vim.cmd('checktime ' .. vim.fn.fnameescape(file))
              end
            elseif #stderr > 0 then
              vim.notify(table.concat(stderr, '\n'), vim.log.levels.WARN, { title = 'apexfmt' })
            else
              vim.notify('apexfmt failed for ' .. file, vim.log.levels.WARN, { title = 'apexfmt' })
            end
          end)
        end,
      })
    end,
  })
end

setup_apex_format_on_save()

return ---@type vim.lsp.Config
{
  apex_jar_path = vim.fn.stdpath('data') .. '/apex-ls/apex-jorje-lsp.jar',
  apex_java_home = nil,
  apex_jvm_max_heap = '2048M',
  cmd = apex_cmd,
  filetypes = { 'apex' },
  root_markers = {
    'sfdx-project.json',
    '.git',
  },
  single_file_support = false,
  init_options = {
    enableEmbeddedSoqlCompletion = true,
    enableErrorToTelemetry = false,
    enableSynchronizedInitJobs = true,
    apexActionClassDefModifiers = 'virtual,abstract',
    apexActionClassAccessModifiers = 'public,global',
    apexActionMethodDefModifiers = 'static,webservice',
    apexActionMethodAccessModifiers = 'public,global',
    apexActionPropDefModifiers = 'static',
    apexActionPropAccessModifiers = 'public,global',
    apexActionClassRestAnnotations = 'RestResource',
    apexActionMethodRestAnnotations = 'HttpGet,HttpPost,HttpPut,HttpPatch,HttpDelete',
    apexActionMethodAnnotations = 'AuraEnabled,InvocableMethod,Future,TestVisible',
    apexOASClassAccessModifiers = 'public,global',
    apexOASMethodAccessModifiers = 'public,global',
    apexOASPropAccessModifiers = 'public,global',
  },
  settings = {
    apex = {
      jvm = {
        completionStatistics = false,
        debugInternalErrors = true,
        debugSemanticErrors = false,
        maxHeap = '2048M',
        disableLwcTypeGeneration = true,
      },
    },
  },
  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = false
    vim.api.nvim_set_option_value('omnifunc', 'v:lua.vim.lsp.omnifunc', {
      buf = bufnr,
    })
  end,
}
