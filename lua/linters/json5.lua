-- /qompassai/Diver/lua/linters/json5.lua
local diagnostic = vim.diagnostic
local fs = vim.fs

return {
  automatic = true,

  cmd = 'npx',

  args = function(context)
    return {
      '--no-install',
      'eslint',
      '--format',
      'json',
      context.filename,
    }
  end,

  append_fname = false,

  cwd = function(context)
    return fs.normalize(context.root)
  end,

  ignore_exitcode = true,

  stdin = false,

  stream = 'stdout',

  parser = function(output)
    if output == '' then
      return {}
    end

    local ok, reports = pcall(vim.json.decode, output)

    if not ok or type(reports) ~= 'table' then
      return {
        {
          lnum = 0,
          col = 0,
          end_lnum = 0,
          end_col = 1,
          severity = diagnostic.severity.ERROR,
          source = 'eslint-json5',
          code = 'invalid-eslint-output',
          message = output:gsub('%s+$', ''),
        },
      }
    end

    local report = reports[1]

    if type(report) ~= 'table' or type(report.messages) ~= 'table' then
      return {}
    end

    local diagnostics = {}

    for _, item in ipairs(report.messages) do
      local line = math.max((tonumber(item.line) or 1) - 1, 0)
      local column = math.max((tonumber(item.column) or 1) - 1, 0)
      local end_line = math.max((tonumber(item.endLine) or item.line or 1) - 1, line)
      local end_column = math.max((tonumber(item.endColumn) or item.column or 1) - 1, column + 1)

      diagnostics[#diagnostics + 1] = {
        lnum = line,
        col = column,
        end_lnum = end_line,
        end_col = end_column,
        severity = item.severity == 2 and diagnostic.severity.ERROR or diagnostic.severity.WARN,
        source = 'eslint-json5',
        code = item.ruleId or 'parse',
        message = item.message or 'ESLint JSON5 diagnostic',
      }
    end

    return diagnostics
  end,

  root_markers = {
    'eslint.config.js',
    'eslint.config.mjs',
    'eslint.config.cjs',
    'package.json',
    '.git',
  },
}