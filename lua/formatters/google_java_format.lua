-- #################################################################
-- ~/.config/nvim/lua/formatters/google_java_format.lua
-- Qompass AI Diver Native google-java-format Adapter
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/google/google-java-format/releases/tag/v1.36.1

local fs = vim.fs

local VERSION = '1.36.1'

local TOOLING = {
    java = 'java',
    jar = fs.joinpath(
        vim.fn.stdpath('data'),
        'formatters',
        'google-java-format',
        'google-java-format-' .. VERSION .. '-all-deps.jar'
    ),
    max_input_bytes = 2 * 1024 * 1024,
    max_output_bytes = 4 * 1024 * 1024,
    initial_heap_mib = 64,
    maximum_heap_mib = 512, -- JVM heap cap, not a total-process memory limit.
    active_processors = 2,
}

-- The formatter parses with internal javac APIs, which JEP 396 hides on
-- JDK 16+. Upstream documents these flags as mandatory there, and the tool
-- itself now requires JDK 21+, so they are unconditional.
local ADD_EXPORTS = {
    'jdk.compiler/com.sun.tools.javac.api',
    'jdk.compiler/com.sun.tools.javac.code',
    'jdk.compiler/com.sun.tools.javac.file',
    'jdk.compiler/com.sun.tools.javac.parser',
    'jdk.compiler/com.sun.tools.javac.tree',
    'jdk.compiler/com.sun.tools.javac.util',
}

local CONFIG = {
    style = 'google', -- 'google' (2-space) | 'aosp' (4-space)
    sort_imports = true,
    remove_unused_imports = true,
    reflow_long_strings = true,
    format_javadoc = true,
}

---@param context FormatterContext
---@return string
local function assume_filename(context)
    if context.filename ~= '' then
        return fs.basename(context.filename)
    end
    return 'stdin.java'
end

---@param context FormatterContext
---@return string[]
local function arguments(context)
    if context.filetype ~= 'java' then
        error('google-java-format requires the java filetype')
    end
    if CONFIG.style ~= 'google' and CONFIG.style ~= 'aosp' then
        error("google-java-format style must be 'google' or 'aosp'")
    end
    local stat = vim.uv.fs_stat(TOOLING.jar)
    if not stat or stat.type ~= 'file' then
        error('Install google-java-format ' .. VERSION .. ' all-deps JAR at ' .. TOOLING.jar)
    end
    local args = {
        '-Xms' .. tostring(TOOLING.initial_heap_mib) .. 'm',
        '-Xmx' .. tostring(TOOLING.maximum_heap_mib) .. 'm',
        '-XX:ActiveProcessorCount=' .. tostring(TOOLING.active_processors),
        '-XX:+UseSerialGC',
        '-Dfile.encoding=UTF-8',
        '-Djava.awt.headless=true',
    }
    for _, export in ipairs(ADD_EXPORTS) do
        args[#args + 1] = '--add-exports=' .. export .. '=ALL-UNNAMED'
    end
    args[#args + 1] = '-jar'
    args[#args + 1] = TOOLING.jar
    if CONFIG.style == 'aosp' then
        args[#args + 1] = '--aosp'
    end
    if not CONFIG.sort_imports then
        args[#args + 1] = '--skip-sorting-imports'
    end
    if not CONFIG.remove_unused_imports then
        args[#args + 1] = '--skip-removing-unused-imports'
    end
    if not CONFIG.reflow_long_strings then
        args[#args + 1] = '--skip-reflowing-long-strings'
    end
    if not CONFIG.format_javadoc then
        args[#args + 1] = '--skip-javadoc-formatting'
    end
    args[#args + 1] = '--assume-filename=' .. assume_filename(context)
    args[#args + 1] = '-' -- stdin in; formatted source on stdout
    return args
end

---@param context FormatterContext
---@return string
local function working_directory(context)
    return context.root
end

---@type FormatterSpec
return {
    cmd = TOOLING.java,
    args = arguments,
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    env = {
        NO_COLOR = '1',
        JAVA_TOOL_OPTIONS = '',
        JDK_JAVA_OPTIONS = '',
        _JAVA_OPTIONS = '',
    },
    root_markers = {
        'pom.xml',
        'build.gradle',
        'build.gradle.kts',
        'settings.gradle',
        'settings.gradle.kts',
        'gradle.properties',
        '.git',
    },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'java',
    decode = nil,
    pre_transform = nil,
}
