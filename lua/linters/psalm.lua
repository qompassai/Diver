-- #################################################################
-- /qompassai/Diver/lua/linters/psalm.lua
-- Native Psalm Linter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/vimeo/psalm/releases/tag/6.17.1
local fs = vim.fs
local uv = vim.uv
local CACHE = fs.joinpath(vim.fn.stdpath('cache'), 'psalm')
-- Complete Psalm 6.17.1 analysis CLI inventory:
--   --clear-cache: disabled
--   --consolidate-cache: disabled
--   --clear-global-cache: disabled
--   --config: Generated private XML, derived from this Lua
--   --debug: disabled
--   --debug-by-line: disabled
--   --debug-performance: disabled
--   --debug-emitted-issues: disabled
--   --diff: disabled
--   --disable-extension: No CLI overrides; normal runtime extension inference
--   --find-dead-code: Disabled alias of find-unused-code
--   --find-unused-code: Disabled; single-file adapter
--   --find-unused-variables: Disabled
--   --find-references-to: Unset; no reference search
--   --help: disabled
--   --ignore-baseline: Enabled
--   --init: disabled
--   --memory-limit: 512M
--   --monochrome: Enabled
--   --no-diff: Enabled
--   --force-jit: Disabled; forceJit=false in XML
--   --no-cache: Disabled; noCache=false in XML
--   --no-reflection-cache: Disabled; reflection cache enabled
--   --no-file-cache: Disabled; file cache enabled
--   --no-reference-cache: Disabled; reference cache enabled
--   --output-format: json
--   --plugin: No CLI plugins; empty XML registration
--   --report: Unset; JSON stdout only
--   --report-show-info: No file report requested
--   --root: Detected absolute project root
--   --set-baseline: Disabled; no baseline writes
--   --show-info: true
--   --show-snippet: false
--   --stats: disabled
--   --threads: 1
--   --scan-threads: 1
--   --update-baseline: disabled
--   --use-baseline: Unset; baselines disabled
--   --use-ini-defaults: Disabled; Psalm normal CLI INI handling
--   --version: disabled
--   --php-version: No CLI override; explicit Composer/runtime inference in ATTRIBUTES
--   --generate-json-map: Unset; no generated map
--   --generate-stubs: Unset; no generated stubs
--   --alter: disabled
--   --review: disabled
--   --language-server: disabled
--   --refactor: disabled
--   --shepherd: Disabled; no remote report upload
--   --no-progress: Enabled
--   --long-progress: disabled
--   --no-suggestions: Enabled
--   --include-php-versions: disabled
--   --pretty-print: disabled
--   --track-tainted-input: disabled
--   --taint-analysis: disabled
--   --security-analysis: disabled
--   --dump-taint-graph: Unset; no graph file
--   --find-unused-psalm-suppress: Disabled
--   --error-level: No CLI override; ATTRIBUTES.errorLevel = 1
local TOOLING = {
    php = '/usr/bin/php',
    executable = 'vendor/bin/psalm',
    memory_limit = '512M',
    timeout = 120000,
}
---@type table<string, string|boolean>
local ATTRIBUTES = {
    autoloader = false,
    cacheDirectory = CACHE,
    errorBaseline = false,
    maxStringLength = '1000',
    maxShapedArraySize = '100',
    longScanWarning = '10.0',
    name = 'Neovim Psalm',
    phpVersion = false,
    serializer = 'php',
    compressor = 'off',
    addParamDefaultToDocblockType = 'false',
    allowFileIncludes = 'true',
    ignoreIncludeSideEffects = 'false',
    respectIncludeOnce = 'false',
    allowStringToStandInForClass = 'false',
    checkForThrowsDocblock = 'false',
    checkForThrowsInGlobalScope = 'false',
    ensureArrayIntOffsetsExist = 'false',
    ensureArrayStringOffsetsExist = 'false',
    ensureOverrideAttribute = 'true',
    findUnusedCode = 'false',
    disallowLiteralKeysOnUnshapedArrays = 'false',
    allFunctionsGlobal = 'false',
    allConstantsGlobal = 'false',
    forceJit = 'false',
    noCache = 'false',
    arrayCache = 'true',
    findUnusedVariablesAndParams = 'false',
    findUnusedPsalmSuppress = 'false',
    findUnusedBaselineEntry = 'false',
    findUnusedIssueHandlerSuppression = 'false',
    hideExternalErrors = 'true',
    hoistConstants = 'false',
    ignoreInternalFunctionFalseReturn = 'false',
    ignoreInternalFunctionNullReturn = 'false',
    includePhpVersionsInErrorBaseline = 'false',
    inferPropertyTypesFromConstructor = 'true',
    memoizeMethodCallResults = 'false',
    rememberPropertyAssignmentsAfterCall = 'true',
    resolveFromConfigFile = 'false',
    strictBinaryOperands = 'true',
    allowBoolToLiteralBoolComparison = 'true',
    throwExceptionOnError = 'false',
    disableVarParsing = 'false',
    errorLevel = '1',
    reportMixedIssues = 'true',
    useDocblockTypes = 'true',
    useDocblockPropertyTypes = 'true',
    docblockPropertyTypesSealProperties = 'true',
    usePhpDocMethodsWithoutMagicCall = 'false',
    usePhpDocPropertiesWithoutMagicCall = 'false',
    skipChecksOnUnresolvableIncludes = 'false',
    sealAllMethods = 'true',
    sealAllProperties = 'true',
    runTaintAnalysis = 'false',
    usePhpStormMetaPath = 'false',
    allowInternalNamedArgumentCalls = 'true',
    allowNamedArgumentCalls = 'true',
    reportInfo = 'true',
    restrictReturnTypes = 'false',
    limitMethodComplexity = 'false',
    disableSuppressAll = 'true',
    triggerErrorExits = 'default',
    threads = '1',
    scanThreads = '1',
}

local ISSUE_HANDLERS = {
    AbstractInstantiation = 'error',
    AbstractMethodCall = 'error',
    AmbiguousConstantInheritance = 'error',
    ArgumentTypeCoercion = 'error',
    AssignmentToVoid = 'error',
    CheckType = 'error',
    CircularReference = 'error',
    ClassMustBeFinal = 'error',
    ComplexFunction = 'error',
    ComplexMethod = 'error',
    ConfigIssue = 'error',
    ConflictingReferenceConstraint = 'error',
    ConstantDeclarationInTrait = 'error',
    ConstructorSignatureMismatch = 'error',
    ContinueOutsideLoop = 'error',
    DeprecatedClass = 'error',
    DeprecatedConstant = 'error',
    DeprecatedFunction = 'error',
    DeprecatedInterface = 'error',
    DeprecatedMethod = 'error',
    DeprecatedProperty = 'error',
    DeprecatedTrait = 'error',
    DirectConstructorCall = 'error',
    DocblockTypeContradiction = 'error',
    DuplicateArrayKey = 'error',
    DuplicateClass = 'error',
    DuplicateConstant = 'error',
    DuplicateEnumCase = 'error',
    DuplicateEnumCaseValue = 'error',
    DuplicateFunction = 'error',
    DuplicateMethod = 'error',
    DuplicateParam = 'error',
    DuplicateProperty = 'error',
    EmptyArrayAccess = 'error',
    ExtensionRequirementViolation = 'error',
    FalsableReturnStatement = 'error',
    FalseOperand = 'error',
    ForbiddenCode = 'error',
    IfThisIsMismatch = 'error',
    ImplementationRequirementViolation = 'error',
    ImplementedParamTypeMismatch = 'error',
    ImplementedReturnTypeMismatch = 'error',
    ImplicitToStringCast = 'error',
    ImpureByReferenceAssignment = 'error',
    ImpureFunctionCall = 'error',
    ImpureMethodCall = 'error',
    ImpurePropertyAssignment = 'error',
    ImpurePropertyFetch = 'error',
    ImpureStaticProperty = 'error',
    ImpureStaticVariable = 'error',
    ImpureVariable = 'error',
    InaccessibleClassConstant = 'error',
    InaccessibleMethod = 'error',
    InaccessibleProperty = 'error',
    IncompatibleTypeParameters = 'error',
    InheritorViolation = 'error',
    InterfaceInstantiation = 'error',
    InternalClass = 'error',
    InternalMethod = 'error',
    InternalProperty = 'error',
    InvalidArgument = 'error',
    InvalidArrayAccess = 'error',
    InvalidArrayAssignment = 'error',
    InvalidArrayOffset = 'error',
    InvalidAttribute = 'error',
    InvalidCast = 'error',
    InvalidCatch = 'error',
    InvalidClass = 'error',
    InvalidClassConstantType = 'error',
    InvalidClone = 'error',
    InvalidConstantAssignmentValue = 'error',
    InvalidDocblock = 'error',
    InvalidDocblockParamName = 'error',
    InvalidEnumBackingType = 'error',
    InvalidEnumCaseValue = 'error',
    InvalidEnumMethod = 'error',
    InvalidExtendClass = 'error',
    InvalidFalsableReturnType = 'error',
    InvalidFunctionCall = 'error',
    InvalidGlobal = 'error',
    InvalidInterfaceImplementation = 'error',
    InvalidIterator = 'error',
    InvalidLiteralArgument = 'error',
    InvalidMethodCall = 'error',
    InvalidNamedArgument = 'error',
    InvalidNullableReturnType = 'error',
    InvalidOperand = 'error',
    InvalidOverride = 'error',
    InvalidParamDefault = 'error',
    InvalidParent = 'error',
    InvalidPassByReference = 'error',
    InvalidPropertyAssignment = 'error',
    InvalidPropertyAssignmentValue = 'error',
    InvalidPropertyFetch = 'error',
    InvalidReturnStatement = 'error',
    InvalidReturnType = 'error',
    InvalidScalarArgument = 'error',
    InvalidScope = 'error',
    InvalidStaticInvocation = 'error',
    InvalidStringClass = 'error',
    InvalidTemplateParam = 'error',
    InvalidThrow = 'error',
    InvalidToString = 'error',
    InvalidTraversableImplementation = 'error',
    InvalidTypeImport = 'error',
    LessSpecificClassConstantType = 'error',
    LessSpecificImplementedReturnType = 'error',
    LessSpecificReturnStatement = 'error',
    LessSpecificReturnType = 'error',
    LiteralKeyUnshapedArray = 'error',
    LoopInvalidation = 'error',
    MethodSignatureMismatch = 'error',
    MethodSignatureMustOmitReturnType = 'error',
    MethodSignatureMustProvideReturnType = 'error',
    MismatchingDocblockParamType = 'error',
    MismatchingDocblockPropertyType = 'error',
    MismatchingDocblockReturnType = 'error',
    MissingClassConstType = 'error',
    MissingClosureParamType = 'error',
    MissingClosureReturnType = 'error',
    MissingConstructor = 'error',
    MissingDependency = 'error',
    MissingDocblockType = 'error',
    MissingFile = 'error',
    MissingImmutableAnnotation = 'error',
    MissingOverrideAttribute = 'error',
    MissingParamType = 'error',
    MissingPropertyType = 'error',
    MissingReturnType = 'error',
    MissingTemplateParam = 'error',
    MissingThrowsDocblock = 'error',
    MixedArgument = 'error',
    MixedArgumentTypeCoercion = 'error',
    MixedArrayAccess = 'error',
    MixedArrayAssignment = 'error',
    MixedArrayOffset = 'error',
    MixedArrayTypeCoercion = 'error',
    MixedAssignment = 'error',
    MixedClone = 'error',
    MixedFunctionCall = 'error',
    MixedMethodCall = 'error',
    MixedOperand = 'error',
    MixedPropertyAssignment = 'error',
    MixedPropertyFetch = 'error',
    MixedPropertyTypeCoercion = 'error',
    MixedReturnStatement = 'error',
    MixedReturnTypeCoercion = 'error',
    MixedStringOffsetAssignment = 'error',
    MoreSpecificImplementedParamType = 'error',
    MoreSpecificReturnType = 'error',
    MutableDependency = 'error',
    NamedArgumentNotAllowed = 'error',
    NoEnumProperties = 'error',
    NoInterfaceProperties = 'error',
    NonInvariantDocblockPropertyType = 'error',
    NonInvariantPropertyType = 'error',
    NonStaticSelfCall = 'error',
    NonVariableReferenceReturn = 'error',
    NoValue = 'error',
    NullableReturnStatement = 'error',
    NullArgument = 'error',
    NullArrayAccess = 'error',
    NullArrayOffset = 'error',
    NullFunctionCall = 'error',
    NullIterator = 'error',
    NullOperand = 'error',
    NullPropertyAssignment = 'error',
    NullPropertyFetch = 'error',
    NullReference = 'error',
    OverriddenFinalConstant = 'error',
    OverriddenInterfaceConstant = 'error',
    OverriddenMethodAccess = 'error',
    OverriddenPropertyAccess = 'error',
    ParadoxicalCondition = 'error',
    ParamNameMismatch = 'error',
    ParentNotFound = 'error',
    PossibleRawObjectIteration = 'error',
    PossiblyFalseArgument = 'error',
    PossiblyFalseIterator = 'error',
    PossiblyFalseOperand = 'error',
    PossiblyFalsePropertyAssignmentValue = 'error',
    PossiblyFalseReference = 'error',
    PossiblyInvalidArgument = 'error',
    PossiblyInvalidArrayAccess = 'error',
    PossiblyInvalidArrayAssignment = 'error',
    PossiblyInvalidArrayOffset = 'error',
    PossiblyInvalidCast = 'error',
    PossiblyInvalidClone = 'error',
    PossiblyInvalidDocblockTag = 'error',
    PossiblyInvalidFunctionCall = 'error',
    PossiblyInvalidIterator = 'error',
    PossiblyInvalidMethodCall = 'error',
    PossiblyInvalidOperand = 'error',
    PossiblyInvalidPropertyAssignment = 'error',
    PossiblyInvalidPropertyAssignmentValue = 'error',
    PossiblyInvalidPropertyFetch = 'error',
    PossiblyNullArgument = 'error',
    PossiblyNullArrayAccess = 'error',
    PossiblyNullArrayAssignment = 'error',
    PossiblyNullArrayOffset = 'error',
    PossiblyNullFunctionCall = 'error',
    PossiblyNullIterator = 'error',
    PossiblyNullOperand = 'error',
    PossiblyNullPropertyAssignment = 'error',
    PossiblyNullPropertyAssignmentValue = 'error',
    PossiblyNullPropertyFetch = 'error',
    PossiblyNullReference = 'error',
    PossiblyUndefinedArrayOffset = 'error',
    PossiblyUndefinedGlobalVariable = 'error',
    PossiblyUndefinedIntArrayOffset = 'error',
    PossiblyUndefinedMethod = 'error',
    PossiblyUndefinedStringArrayOffset = 'error',
    PossiblyUndefinedVariable = 'error',
    PossiblyUnusedMethod = 'error',
    PossiblyUnusedParam = 'error',
    PossiblyUnusedProperty = 'error',
    PossiblyUnusedReturnValue = 'error',
    PrivateFinalMethod = 'error',
    PropertyNotSetInConstructor = 'error',
    PropertyTypeCoercion = 'error',
    RawObjectIteration = 'error',
    RedundantCast = 'error',
    RedundantCastGivenDocblockType = 'error',
    RedundantCondition = 'error',
    RedundantConditionGivenDocblockType = 'error',
    RedundantFlag = 'error',
    RedundantFunctionCall = 'error',
    RedundantFunctionCallGivenDocblockType = 'error',
    RedundantIdentityWithTrue = 'error',
    RedundantPropertyInitializationCheck = 'error',
    ReferenceConstraintViolation = 'error',
    ReferenceReusedFromConfusingScope = 'error',
    ReservedWord = 'error',
    RiskyCast = 'error',
    RiskyTruthyFalsyComparison = 'error',
    StringIncrement = 'error',
    TaintedCallable = 'error',
    TaintedCookie = 'error',
    TaintedCustom = 'error',
    TaintedEval = 'error',
    TaintedExtract = 'error',
    TaintedFile = 'error',
    TaintedHeader = 'error',
    TaintedHtml = 'error',
    TaintedInclude = 'error',
    TaintedInput = 'error',
    TaintedLdap = 'error',
    TaintedShell = 'error',
    TaintedSleep = 'error',
    TaintedSql = 'error',
    TaintedSSRF = 'error',
    TaintedSystemSecret = 'error',
    TaintedTextWithQuotes = 'error',
    TaintedUnserialize = 'error',
    TaintedUserSecret = 'error',
    TaintedXpath = 'error',
    TooFewArguments = 'error',
    TooManyArguments = 'error',
    TooManyTemplateParams = 'error',
    Trace = 'error',
    TraitMethodSignatureMismatch = 'error',
    TypeDoesNotContainNull = 'error',
    TypeDoesNotContainType = 'error',
    UncaughtThrowInGlobalScope = 'error',
    UndefinedAttributeClass = 'error',
    UndefinedClass = 'error',
    UndefinedConstant = 'error',
    UndefinedDocblockClass = 'error',
    UndefinedFunction = 'error',
    UndefinedGlobalVariable = 'error',
    UndefinedInterface = 'error',
    UndefinedInterfaceMethod = 'error',
    UndefinedMagicMethod = 'error',
    UndefinedMagicPropertyAssignment = 'error',
    UndefinedMagicPropertyFetch = 'error',
    UndefinedMethod = 'error',
    UndefinedPropertyAssignment = 'error',
    UndefinedPropertyFetch = 'error',
    UndefinedThisPropertyAssignment = 'error',
    UndefinedThisPropertyFetch = 'error',
    UndefinedTrace = 'error',
    UndefinedTrait = 'error',
    UndefinedVariable = 'error',
    UnevaluatedCode = 'error',
    UnhandledMatchCondition = 'error',
    UnimplementedAbstractMethod = 'error',
    UnimplementedInterfaceMethod = 'error',
    UninitializedProperty = 'error',
    UnnecessaryVarAnnotation = 'error',
    UnrecognizedExpression = 'error',
    UnrecognizedStatement = 'error',
    UnresolvableConstant = 'error',
    UnresolvableInclude = 'error',
    UnsafeGenericInstantiation = 'error',
    UnsafeInstantiation = 'error',
    UnsupportedPropertyReferenceUsage = 'error',
    UnsupportedReferenceUsage = 'error',
    UnusedBaselineEntry = 'error',
    UnusedClass = 'error',
    UnusedClosureParam = 'error',
    UnusedConstructor = 'error',
    UnusedDocblockParam = 'error',
    UnusedIssueHandlerSuppression = 'error',
    UnusedForeachValue = 'error',
    UnusedFunctionCall = 'error',
    UnusedMethod = 'error',
    UnusedMethodCall = 'error',
    UnusedParam = 'error',
    UnusedProperty = 'error',
    UnusedPsalmSuppress = 'error',
    UnusedReturnValue = 'error',
    UnusedVariable = 'error',
}
---@type table<string, string|boolean>
local OPTIONAL_XML = {
    extraFiles = false,
    taintAnalysis = false,
    mockClasses = false,
    stubs = false,
    plugins = '<plugins/>',
    forbiddenFunctions = false,
    forbiddenConstants = false,
    ignoreExceptions = false,
    globals = false,
    universalObjectCrates = false,
    enableExtensions = false,
    disableExtensions = false,
}
local FILE_EXTENSIONS = {
    'php',
}
local ROOT_MARKERS = {
    'composer.json',
    '.git',
}
local LIMITS = {
    output = 16 * 1024 * 1024,
    records = 10000,
    diagnostics = 512,
    message = 4096,
}
local SEVERITIES = { error = vim.diagnostic.severity.ERROR, info = vim.diagnostic.severity.INFO }
---@type string?
local directory
---@type table<string, string>
local profiles = {}
local profile_count = 0

---@param value string
---@return string
local function xml(value)
    assert(not value:find('[%z\1-\8\11\12\14-\31]'), 'Invalid control character in Psalm XML value')
    return (value:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'):gsub('"', '&quot;'):gsub("'", '&apos;'))
end

---@param context LintContext
---@return string
local function root(context)
    return fs.root(context.filename, ROOT_MARKERS) or context.root or context.cwd
end

---@param path string
---@param cwd string
---@return string
local function canonical(path, cwd)
    if path:sub(1, 1) ~= '/' then
        path = fs.joinpath(cwd, path)
    end
    path = fs.normalize(path)
    return uv.fs_realpath(path) or path
end

local function cleanup()
    for _, path in pairs(profiles) do
        uv.fs_unlink(path)
    end
    if directory then
        uv.fs_rmdir(directory)
    end
end

---@param cwd string
---@return string
local function profile_path(cwd)
    if profiles[cwd] then
        return profiles[cwd]
    end
    assert(profile_count < 128, 'Psalm profile limit reached; restart Neovim')
    local lines = {
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<psalm xmlns="https://getpsalm.org/schema/config"',
    }
    for _, name in ipairs(vim.fn.sort(vim.tbl_keys(ATTRIBUTES))) do
        local value = ATTRIBUTES[name]
        if type(value) == 'string' then
            lines[#lines + 1] = '  ' .. name .. '="' .. xml(value) .. '"'
        else
            assert(value == false, 'Psalm attribute must be a string or false: ' .. name)
        end
    end
    lines[#lines + 1] = '>'
    lines[#lines + 1] = '<projectFiles><directory name="'
        .. xml(cwd)
        .. '" ignoreTypeStats="false" resolveSymlinks="false" useStrictTypes="false"/>'
        .. '<ignoreFiles allowMissingFiles="true"><directory name="'
        .. xml(fs.joinpath(cwd, 'vendor'))
        .. '"/></ignoreFiles></projectFiles>'
    lines[#lines + 1] = '<fileExtensions>'
    for _, extension in ipairs(FILE_EXTENSIONS) do
        lines[#lines + 1] = '<extension name="' .. xml(extension) .. '"/>'
    end
    lines[#lines + 1] = '</fileExtensions>'
    for _, name in ipairs(vim.fn.sort(vim.tbl_keys(OPTIONAL_XML))) do
        local value = OPTIONAL_XML[name]
        if type(value) == 'string' then
            lines[#lines + 1] = value
        end
    end
    lines[#lines + 1] = '<issueHandlers>'
    for _, name in ipairs(vim.fn.sort(vim.tbl_keys(ISSUE_HANDLERS))) do
        local level = ISSUE_HANDLERS[name]
        assert(level == 'error' or level == 'info' or level == 'suppress', 'Invalid Psalm issue level')
        lines[#lines + 1] = '<' .. name .. ' errorLevel="' .. level .. '"/>'
    end
    lines[#lines + 1] = '</issueHandlers></psalm>'
    local content = table.concat(lines, '\n') .. '\n'
    if not directory then
        directory = assert(uv.fs_mkdtemp(vim.fn.tempname() .. '-psalm-XXXXXX'))
        vim.api.nvim_create_autocmd('VimLeavePre', {
            once = true,
            callback = cleanup,
            desc = 'Remove private Psalm profiles',
        })
    end
    local path = fs.joinpath(directory, tostring(profile_count + 1) .. '.xml')
    local fd = assert(uv.fs_open(path, 'wx', 384))
    local offset = 0
    while offset < #content do
        local written, problem = uv.fs_write(fd, content:sub(offset + 1), offset)
        if not written or written == 0 then
            uv.fs_close(fd)
            uv.fs_unlink(path)
            error(problem or 'Cannot write Psalm XML')
        end
        offset = offset + written
    end
    assert(uv.fs_close(fd))
    profiles[cwd] = path
    profile_count = profile_count + 1
    return path
end

---@param context LintContext
---@return string[]
local function arguments(context)
    assert(context.filename ~= '' and not context.modified, 'Psalm requires a named, saved buffer')
    local cwd = root(context)
    local executable = fs.joinpath(cwd, TOOLING.executable)
    assert(vim.fn.filereadable(executable) == 1, 'Install project-local vimeo/psalm:6.17.1')
    local filename = canonical(context.filename, context.cwd)
    local stat = uv.fs_stat(filename)
    assert(stat and stat.type == 'file', 'Psalm input must be an existing regular file')
    vim.fn.mkdir(CACHE, 'p')
    assert(uv.fs_chmod(CACHE, 448), 'Cannot protect Psalm cache directory')
    return {
        executable,
        '--config=' .. profile_path(cwd),
        '--root=' .. cwd,
        '--output-format=json',
        '--memory-limit=' .. TOOLING.memory_limit,
        '--threads=1',
        '--scan-threads=1',
        '--no-diff',
        '--ignore-baseline',
        '--monochrome',
        '--no-progress',
        '--show-info=true',
        '--show-snippet=false',
        '--no-suggestions',
        '--',
        filename,
    }
end

---@param value string
---@return string
local function clean(value)
    local message = vim.trim(value:gsub('[%z\1-\31\127]', ' '))
    if #message > LIMITS.message then
        local last = LIMITS.message - 3
        while last > 0 do
            local byte = message:byte(last + 1)
            if not byte or byte < 128 or byte >= 192 then
                break
            end
            last = last - 1
        end
        message = message:sub(1, last) .. '...'
    end
    return message
end

---@param context LintContext
---@param code string
---@param message string
---@return vim.Diagnostic
local function status(context, code, message)
    return {
        bufnr = context.bufnr,
        lnum = 0,
        end_lnum = 0,
        col = 0,
        end_col = 0,
        severity = vim.diagnostic.severity.WARN,
        source = 'psalm',
        code = code,
        message = clean(message),
    }
end

local function positive_integer(value)
    return type(value) == 'number' and value >= 1 and value < 2147483647 and value == math.floor(value)
end

---@param context LintContext
---@param line any
---@param column any
---@return integer?, integer?
local function position(context, line, column)
    if not positive_integer(line) or not positive_integer(column) then
        return nil, nil
    end
    local row = math.min(line - 1, vim.api.nvim_buf_line_count(context.bufnr) - 1)
    local text = vim.api.nvim_buf_get_lines(context.bufnr, row, row + 1, false)[1] or ''
    local col = math.min(column - 1, #text)
    while col > 0 do
        local byte = text:byte(col + 1)
        if not byte or byte < 128 or byte >= 192 then
            break
        end
        col = col - 1
    end
    return row, col
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
    if context.modified then
        return {
            status(context, 'save-required', 'Save this buffer before running Psalm.'),
        }
    end
    if #output > LIMITS.output then
        return {
            status(context, 'output-limit', 'Psalm output exceeded 16 MiB.'),
        }
    end
    local text = vim.trim(output)
    local ok, report = pcall(vim.json.decode, text)
    if not ok or type(report) ~= 'table' or not vim.islist(report) or text:sub(1, 1) ~= '[' then
        return {
            status(
                context,
                'invalid-report',
                'Psalm returned no valid JSON report; inspect stderr, configuration and PHP requirements.'
            ),
        }
    end
    ---@type vim.Diagnostic[]
    local result = {}
    local malformed, foreign = false, false
    local limited = #report > LIMITS.records
    local target = canonical(context.filename, context.cwd)
    for index = 1, math.min(#report, LIMITS.records) do
        if #result >= LIMITS.diagnostics then
            limited = true
            break
        end
        local issue = report[index]
        if
            type(issue) ~= 'table'
            or type(issue.message) ~= 'string'
            or issue.message == ''
            or type(issue.file_path) ~= 'string'
            or issue.file_path == ''
            or type(issue.type) ~= 'string'
            or issue.type == ''
            or not SEVERITIES[issue.severity]
        then
            malformed = true
        elseif canonical(issue.file_path, root(context)) ~= target then
            foreign = true
        else
            local item = status(context, clean(issue.type), issue.message)
            item.severity = SEVERITIES[issue.severity]
            local row, col = position(context, issue.line_from, issue.column_from)
            local end_row, end_col = position(context, issue.line_to, issue.column_to)
            if row and col then
                item.lnum, item.col = row, col
                item.end_lnum, item.end_col = row, col
                if end_row and end_col and (end_row > row or (end_row == row and end_col >= col)) then
                    item.end_lnum, item.end_col = end_row, end_col
                end
            end
            item.user_data = {
                file_path = issue.file_path,
                reported_line = issue.line_from,
                reported_column = issue.column_from,
                reported_end_line = issue.line_to,
                reported_end_column = issue.column_to,
                shortcode = issue.shortcode,
            }
            result[#result + 1] = item
        end
    end
    if malformed then
        result[#result + 1] =
            status(context, 'malformed-result', 'Some Psalm results were malformed; results are incomplete.')
    end
    if foreign then
        result[#result + 1] = status(
            context,
            'other-files',
            'Psalm reported issues outside this buffer; run project analysis to inspect them.'
        )
    end
    if limited then
        result[#result + 1] = status(
            context,
            'result-limit',
            'Psalm reached the editor result limit; run project analysis for all findings.'
        )
    end
    return result
end

---@type Linter
return {
    cmd = TOOLING.php,
    args = arguments,
    append_fname = false,
    automatic = true,
    cwd = root,
    env = {
        NO_COLOR = '1',
        RUNNER_DEBUG = '0',
    },
    exit_codes = { 0, 2 },
    ignore_exitcode = false,
    parser = parse,
    root_markers = ROOT_MARKERS,
    stdin = false,
    stream = 'stdout',
    timeout = TOOLING.timeout,
}
