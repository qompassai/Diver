-- #################################################################
-- /qompassai/Diver/lua/linters/perlcritic.lua
-- Native Perl::Critic Linter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/Perl-Critic/Perl-Critic
--   local lint = require('linters')
--   lint.register('perlcritic', require('linters.perlcritic'))
--   lint.linters_by_ft.perl = lint.linters_by_ft.perl or {}
--   if not vim.tbl_contains(lint.linters_by_ft.perl, 'perlcritic') then
--     table.insert(lint.linters_by_ft.perl, 'perlcritic')
--   end
local PROFILE = [==[
criticism-fatal = 0
severity = 1
force = 0
only = 1
allow-unsafe = 0
profile-strictness = fatal
color = 0
pager =
top = 0
verbose = 8
include =
exclude =
single-policy =
theme =
color-severity-highest = bold red
color-severity-high = magenta
color-severity-medium =
color-severity-low =
color-severity-lowest =
program-extensions = .pl .pm .t .psgi
[BuiltinFunctions::ProhibitBooleanGrep]
set_themes                         = certrec core pbp performance
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[BuiltinFunctions::ProhibitComplexMappings]
set_themes                         = complexity core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
max_statements = 1
[BuiltinFunctions::ProhibitLvalueSubstr]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[BuiltinFunctions::ProhibitReverseSortBlock]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
[BuiltinFunctions::ProhibitShiftRef]
set_themes                         = bugs core tests
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[BuiltinFunctions::ProhibitSleepViaSelect]
set_themes                         = bugs core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[BuiltinFunctions::ProhibitStringyEval]
set_themes                         = bugs certrule core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
allow_includes = 0
[BuiltinFunctions::ProhibitStringySplit]
set_themes                         = certrule core cosmetic pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[BuiltinFunctions::ProhibitUniversalCan]
set_themes                         = certrule core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[BuiltinFunctions::ProhibitUniversalIsa]
set_themes                         = certrule core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[BuiltinFunctions::ProhibitUselessTopic]
set_themes                         = core
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[BuiltinFunctions::ProhibitVoidGrep]
set_themes                         = core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[BuiltinFunctions::ProhibitVoidMap]
set_themes                         = core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[BuiltinFunctions::RequireBlockGrep]
set_themes                         = bugs core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[BuiltinFunctions::RequireBlockMap]
set_themes                         = bugs core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[BuiltinFunctions::RequireGlobFunction]
set_themes                         = bugs core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[BuiltinFunctions::RequireSimpleSortBlock]
set_themes                         = complexity core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[ClassHierarchies::ProhibitAutoloading]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[ClassHierarchies::ProhibitExplicitISA]
set_themes                         = certrec core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[ClassHierarchies::ProhibitOneArgBless]
set_themes                         = bugs core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[CodeLayout::ProhibitHardTabs]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
allow_leading_tabs = 1
[CodeLayout::ProhibitParensWithBuiltins]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
[CodeLayout::ProhibitQuotedWordLists]
set_themes                         = core cosmetic
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
min_elements = 2
strict = 0
[CodeLayout::ProhibitTrailingWhitespace]
set_themes                         = core maintenance
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
[CodeLayout::RequireConsistentNewlines]
set_themes                         = bugs core
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[CodeLayout::RequireTidyCode]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
perltidyrc =
[CodeLayout::RequireTrailingCommas]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
[ControlStructures::ProhibitCStyleForLoops]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[ControlStructures::ProhibitCascadingIfElse]
set_themes                         = complexity core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
max_elsif = 2
[ControlStructures::ProhibitDeepNests]
set_themes                         = complexity core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
max_nests = 5
[ControlStructures::ProhibitLabelsWithSpecialBlockNames]
set_themes                         = bugs core
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[ControlStructures::ProhibitMutatingListFunctions]
set_themes                         = bugs certrule core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
list_funcs = map grep List::Util::first List::MoreUtils::any List::SomeUtils::any List::MoreUtils::all List::SomeUtils::all List::MoreUtils::none List::SomeUtils::none List::MoreUtils::notall List::SomeUtils::notall List::MoreUtils::true List::SomeUtils::true List::MoreUtils::false List::SomeUtils::false List::MoreUtils::firstidx List::SomeUtils::firstidx List::MoreUtils::first_index List::SomeUtils::first_index List::MoreUtils::lastidx List::SomeUtils::lastidx List::MoreUtils::last_index List::SomeUtils::last_index List::MoreUtils::insert_after List::SomeUtils::insert_after List::MoreUtils::insert_after_string List::SomeUtils::insert_after_string
add_list_funcs =
[ControlStructures::ProhibitNegativeExpressionsInUnlessAndUntilConditions]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[ControlStructures::ProhibitPostfixControls]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
allow =
flowcontrol = carp cluck confess croak die exit goto warn
[ControlStructures::ProhibitUnlessBlocks]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[ControlStructures::ProhibitUnreachableCode]
set_themes                         = bugs certrec core
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[ControlStructures::ProhibitUntilBlocks]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[ControlStructures::ProhibitYadaOperator]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[-Documentation::PodSpelling]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
spell_command = aspell list
stop_words =
stop_words_file =
[Documentation::RequirePackageMatchesPodName]
set_themes                         = core cosmetic
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
[Documentation::RequirePodAtEnd]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
[Documentation::RequirePodSections]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
lib_sections =
script_sections =
source = book_first_edition
language =
[ErrorHandling::RequireCarping]
set_themes                         = certrule core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
allow_messages_ending_with_newlines = 1
allow_in_main_unless_in_subroutine = 0
[ErrorHandling::RequireCheckingReturnValueOfEval]
set_themes                         = bugs core
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[InputOutput::ProhibitBacktickOperators]
set_themes                         = core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
only_in_void_context =
[InputOutput::ProhibitBarewordDirHandles]
set_themes                         = bugs certrec core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[InputOutput::ProhibitBarewordFileHandles]
set_themes                         = bugs certrec core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[InputOutput::ProhibitExplicitStdin]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[InputOutput::ProhibitInteractiveTest]
set_themes                         = bugs certrule core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[InputOutput::ProhibitJoinedReadline]
set_themes                         = core pbp performance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[InputOutput::ProhibitOneArgSelect]
set_themes                         = bugs certrule core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[InputOutput::ProhibitReadlineInForLoop]
set_themes                         = bugs core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[InputOutput::ProhibitTwoArgOpen]
set_themes                         = bugs certrule core pbp security
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[InputOutput::RequireBracedFileHandleWithPrint]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
[InputOutput::RequireBriefOpen]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
lines = 9
[InputOutput::RequireCheckedClose]
set_themes                         = certrule core maintenance
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
autodie_modules = autodie
[InputOutput::RequireCheckedOpen]
set_themes                         = certrule core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
autodie_modules = autodie
[InputOutput::RequireCheckedSyscalls]
set_themes                         = certrule core maintenance
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
functions = open close print say
exclude_functions =
autodie_modules = autodie
[InputOutput::RequireEncodingWithUTF8Layer]
set_themes                         = bugs core security
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[Miscellanea::ProhibitFormats]
set_themes                         = certrule core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[Miscellanea::ProhibitTies]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[Miscellanea::ProhibitUnrestrictedNoCritic]
set_themes                         = core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[Miscellanea::ProhibitUselessNoCritic]
set_themes                         = core maintenance
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[Modules::ProhibitAutomaticExportation]
set_themes                         = bugs core
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[Modules::ProhibitConditionalUseStatements]
set_themes                         = bugs core
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[Modules::ProhibitEvilModules]
set_themes                         = bugs certrule core
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
modules = Class::ISA {Found use of Class::ISA. This module is deprecated by the Perl 5 Porters.} Pod::Plainer {Found use of Pod::Plainer. This module is deprecated by the Perl 5 Porters.} Shell {Found use of Shell. This module is deprecated by the Perl 5 Porters.} Switch {Found use of Switch. This module is deprecated by the Perl 5 Porters.}
modules_file =
[Modules::ProhibitExcessMainComplexity]
set_themes                         = complexity core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
max_mccabe = 20
[Modules::ProhibitMultiplePackages]
set_themes                         = bugs core
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[Modules::RequireBarewordIncludes]
set_themes                         = core portability
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[Modules::RequireEndWithOne]
set_themes                         = bugs certrule core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[Modules::RequireExplicitPackage]
set_themes                         = bugs core
add_themes                         =
severity                           = 4
maximum_violations_per_document    = 1
exempt_scripts = 1
allow_import_of =
[Modules::RequireFilenameMatchesPackage]
set_themes                         = bugs core
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[Modules::RequireNoMatchVarsWithUseEnglish]
set_themes                         = core performance
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[Modules::RequireVersionVar]
set_themes                         = core pbp readability
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[NamingConventions::Capitalization]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
packages = :starts_with_upper
package_exemptions = main
subroutines = :single_case
subroutine_exemptions = AUTOLOAD BUILD BUILDARGS CLEAR CLOSE DELETE DEMOLISH DESTROY EXISTS EXTEND FETCH FETCHSIZE FIRSTKEY GETC NEXTKEY POP PRINT PRINTF PUSH READ READLINE SCALAR SHIFT SPLICE STORE STORESIZE TIEARRAY TIEHANDLE TIEHASH TIESCALAR UNSHIFT UNTIE WRITE
local_lexical_variables = :single_case
local_lexical_variable_exemptions =
scoped_lexical_variables = :single_case
scoped_lexical_variable_exemptions =
file_lexical_variables = :single_case
file_lexical_variable_exemptions =
global_variables = :single_case
global_variable_exemptions = \$VERSION @ISA @EXPORT(?:_OK)? %EXPORT_TAGS \$AUTOLOAD %ENV %SIG \$TODO
constants = :all_upper
constant_exemptions =
labels = :all_upper
label_exemptions =
[NamingConventions::ProhibitAmbiguousNames]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
forbid = abstract bases close contract last left no record right second set
[Objects::ProhibitIndirectSyntax]
set_themes                         = certrule core maintenance pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
forbid =
[References::ProhibitDoubleSigils]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[RegularExpressions::ProhibitCaptureWithoutTest]
set_themes                         = certrule core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
exception_source =
[RegularExpressions::ProhibitComplexRegexes]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
max_characters = 60
[RegularExpressions::ProhibitEnumeratedClasses]
set_themes                         = core cosmetic pbp unicode
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
[RegularExpressions::ProhibitEscapedMetacharacters]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
[RegularExpressions::ProhibitFixedStringMatches]
set_themes                         = core pbp performance
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[RegularExpressions::ProhibitSingleCharAlternation]
set_themes                         = core pbp performance
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
[RegularExpressions::ProhibitUnusedCapture]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[RegularExpressions::ProhibitUnusualDelimiters]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
allow_all_brackets =
[RegularExpressions::ProhibitUselessTopic]
set_themes                         = core
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[RegularExpressions::RequireBracesForMultiline]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
allow_all_brackets =
[RegularExpressions::RequireDotMatchAnything]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[RegularExpressions::RequireExtendedFormatting]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
minimum_regex_length_to_complain_about = 0
strict = 0
[RegularExpressions::RequireLineBoundaryMatching]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[Subroutines::ProhibitAmpersandSigils]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[Subroutines::ProhibitBuiltinHomonyms]
set_themes                         = bugs certrule core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
allow =
[Subroutines::ProhibitExcessComplexity]
set_themes                         = complexity core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
max_mccabe = 20
[Subroutines::ProhibitExplicitReturnUndef]
set_themes                         = bugs certrec core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[Subroutines::ProhibitManyArgs]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
max_arguments = 5
skip_object = 0
[Subroutines::ProhibitNestedSubs]
set_themes                         = bugs core
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[Subroutines::ProhibitReturnSort]
set_themes                         = bugs certrule core
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[Subroutines::ProhibitSubroutinePrototypes]
set_themes                         = bugs certrec core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[Subroutines::ProhibitUnusedPrivateSubroutines]
set_themes                         = certrec core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
private_name_regex = \b_\w+\b
allow =
skip_when_using =
allow_name_regex =
[Subroutines::ProtectPrivateSubs]
set_themes                         = certrule core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
private_name_regex = \b_\w+\b
allow =
[Subroutines::RequireArgUnpacking]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
short_subroutine_statements = 0
allow_subscripts = 0
allow_delegation_to =
allow_closures = 0
[Subroutines::RequireFinalReturn]
set_themes                         = bugs certrec core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
terminal_funcs =
terminal_methods =
[TestingAndDebugging::ProhibitNoStrict]
set_themes                         = bugs certrec core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
allow =
[TestingAndDebugging::ProhibitNoWarnings]
set_themes                         = bugs certrec core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
allow =
allow_with_category_restriction = 0
[TestingAndDebugging::ProhibitProlongedStrictureOverride]
set_themes                         = bugs certrec core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
statements = 3
[TestingAndDebugging::RequireTestLabels]
set_themes                         = core maintenance tests
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
modules =
[TestingAndDebugging::RequireUseStrict]
set_themes                         = bugs certrec certrule core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = 1
equivalent_modules =
[TestingAndDebugging::RequireUseWarnings]
set_themes                         = bugs certrule core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = 1
equivalent_modules =
[ValuesAndExpressions::ProhibitCommaSeparatedStatements]
set_themes                         = bugs certrule core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
allow_last_statement_to_be_comma_separated_in_map_and_grep = 0
[ValuesAndExpressions::ProhibitComplexVersion]
set_themes                         = core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
forbid_use_version = 0
[ValuesAndExpressions::ProhibitConstantPragma]
set_themes                         = bugs core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[ValuesAndExpressions::ProhibitEmptyQuotes]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[ValuesAndExpressions::ProhibitEscapedCharacters]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[ValuesAndExpressions::ProhibitImplicitNewlines]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[ValuesAndExpressions::ProhibitInterpolationOfLiterals]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
allow =
allow_if_string_contains_single_quote = 0
[ValuesAndExpressions::ProhibitLeadingZeros]
set_themes                         = bugs certrec core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
strict = 0
[ValuesAndExpressions::ProhibitLongChainsOfMethodCalls]
set_themes                         = core maintenance
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
max_chain_length = 3
[ValuesAndExpressions::ProhibitMagicNumbers]
set_themes                         = certrec core maintenance
add_themes                         =
severity                           = 2
maximum_violations_per_document    = 10
allowed_values = 0 1 2
allowed_types = Float
allow_to_the_right_of_a_fat_comma = 1
constant_creator_subroutines =
[ValuesAndExpressions::ProhibitMismatchedOperators]
set_themes                         = bugs certrule core
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[ValuesAndExpressions::ProhibitMixedBooleanOperators]
set_themes                         = bugs certrec core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[ValuesAndExpressions::ProhibitNoisyQuotes]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[ValuesAndExpressions::ProhibitQuotesAsQuotelikeOperatorDelimiters]
set_themes                         = core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
single_quote_allowed_operators = m s qr qx
double_quote_allowed_operators =
back_quote_allowed_operators =
[ValuesAndExpressions::ProhibitSpecialLiteralHeredocTerminator]
set_themes                         = core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[ValuesAndExpressions::ProhibitVersionStrings]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[ValuesAndExpressions::RequireConstantVersion]
set_themes                         = core maintenance
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
allow_version_without_use_on_same_line = 0
[ValuesAndExpressions::RequireInterpolationOfMetachars]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 1
maximum_violations_per_document    = no_limit
rcs_keywords =
[ValuesAndExpressions::RequireNumberSeparators]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
min_value = 10_000
[ValuesAndExpressions::RequireQuotedHeredocTerminator]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[ValuesAndExpressions::RequireUpperCaseHeredocTerminator]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[Variables::ProhibitAugmentedAssignmentInDeclaration]
set_themes                         = bugs core
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
allow_our = 0
[Variables::ProhibitConditionalDeclarations]
set_themes                         = bugs core
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[-Variables::ProhibitEvilVariables]
set_themes                         = bugs core
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
variables =
variables_file =
[Variables::ProhibitLocalVars]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[Variables::ProhibitMatchVars]
set_themes                         = core pbp performance
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
[Variables::ProhibitPackageVars]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
packages = Data::Dumper File::Find FindBin Log::Log4perl Test::Builder Text::Wrap
add_packages =
[Variables::ProhibitPerl4PackageNames]
set_themes                         = certrec core maintenance
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
[Variables::ProhibitPunctuationVars]
set_themes                         = core cosmetic pbp
add_themes                         =
severity                           = 2
maximum_violations_per_document    = no_limit
allow =
string_mode = thorough
[Variables::ProhibitReusedNames]
set_themes                         = bugs core
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
allow = $self $class
[Variables::ProhibitUnusedVariables]
set_themes                         = certrec core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[Variables::ProtectPrivateVars]
set_themes                         = certrule core maintenance
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[Variables::RequireInitializationForLocalVars]
set_themes                         = bugs certrec core pbp
add_themes                         =
severity                           = 3
maximum_violations_per_document    = no_limit
[Variables::RequireLexicalLoopIterators]
set_themes                         = bugs certrec core pbp
add_themes                         =
severity                           = 5
maximum_violations_per_document    = no_limit
[Variables::RequireLocalizedPunctuationVars]
set_themes                         = bugs certrec core pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
allow =
[Variables::RequireNegativeIndices]
set_themes                         = core maintenance pbp
add_themes                         =
severity                           = 4
maximum_violations_per_document    = no_limit
]==]

local RECORD = string.char(30)
local FIELD = string.char(31)
local FORMAT = RECORD .. table.concat({
  '%l',
  '%c',
  '%s',
  '%P',
  '%m',
  '%e',
  '%f',
}, FIELD)
local CLI = {
  quiet = true,
  statistics = false,
  statistics_only = false,
  count = false,
  files_with_violations = false,
  files_without_violations = false,
  help = false,
  options = false,
  man = false,
  version = false,
  list = false,
  list_enabled = false,
  list_themes = false,
  profile_proto = false,
  doc = '',
}
local LIMITS = { output = 16 * 1024 * 1024, records = 10000, diagnostics = 512, message = 4096 }
local ROOT_MARKERS = {
  'cpanfile',
  'Makefile.PL',
  'Build.PL',
  'dist.ini',
  '.git',
}
local SEVERITIES = {
  [1] = vim.diagnostic.severity.HINT,
  [2] = vim.diagnostic.severity.INFO,
  [3] = vim.diagnostic.severity.WARN,
  [4] = vim.diagnostic.severity.ERROR,
  [5] = vim.diagnostic.severity.ERROR,
}
local uv = vim.uv
local fs = vim.fs
---@type string?
local directory
---@type string?
local profile

local function cleanup()
  if profile then
    uv.fs_unlink(profile)
  end
  if directory then
    uv.fs_rmdir(directory)
  end
end

---@return string
local function profile_path()
  if profile then
    return profile
  end
  if not directory then
    directory = assert(uv.fs_mkdtemp(vim.fn.tempname() .. '-perlcritic-XXXXXX'))
    vim.api.nvim_create_autocmd('VimLeavePre', {
      once = true,
      callback = cleanup,
      desc = 'Remove private Perl::Critic profile',
    })
  end
  local path = fs.joinpath(directory, 'perlcriticrc')
  local fd = assert(uv.fs_open(path, 'wx', 384)) -- 0600, exclusive; directory is 0700.
  local offset = 0
  while offset < #PROFILE do
    local written, problem = uv.fs_write(fd, PROFILE:sub(offset + 1), offset)
    if not written or written == 0 then
      uv.fs_close(fd)
      uv.fs_unlink(path)
      error(problem or 'Cannot write Perl::Critic profile')
    end
    offset = offset + written
  end
  assert(uv.fs_close(fd))
  profile = path
  return path
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

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(context.filename ~= '' and not context.modified, 'Perl::Critic requires a named, saved buffer')
  local filename = canonical(context.filename, context.cwd)
  local stat = uv.fs_stat(filename)
  assert(stat and stat.type == 'file', 'Perl::Critic input must be a saved regular file')
  for name, value in pairs(CLI) do
    if name ~= 'quiet' then
      assert(value == false or value == '', 'Perl::Critic reporting mode is incompatible: ' .. name)
    end
  end
  assert(CLI.quiet, 'Quiet mode is required for clean diagnostic output')
  return {
    '--profile',
    profile_path(),
    '--verbose',
    FORMAT,
    '--quiet',
    '--nocolor',
    '--nostatistics',
    '--nostatistics-only',
    '--',
    filename,
  }
end

---@param value string
---@return string
local function clean(value)
  local text = vim.trim(value:gsub('[%z\1-\31\127]', ' '))
  if #text > LIMITS.message then
    local last = LIMITS.message - 3
    while last > 0 do
      local byte = text:byte(last + 1)
      if not byte or byte < 128 or byte >= 192 then
        break
      end
      last = last - 1
    end
    text = text:sub(1, last) .. '...'
  end
  return text
end

---@param context LintContext
---@param code string
---@param message string
---@return vim.Diagnostic
local function status(context, code, message)
  return {
    bufnr = context.bufnr,
    lnum = 0,
    col = 0,
    end_lnum = 0,
    end_col = 0,
    source = 'perlcritic',
    severity = vim.diagnostic.severity.WARN,
    code = code,
    message = clean(message),
  }
end

local function positive_integer(value)
  local number = tonumber(value)
  if number and number >= 1 and number < 2147483647 and number == math.floor(number) then
    return number
  end
  return nil
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  if context.modified then
    return { status(context, 'save-required', 'Save this buffer before running Perl::Critic.') }
  end
  if #output > LIMITS.output then
    return { status(context, 'output-limit', 'Perl::Critic output exceeded 16 MiB.') }
  end
  if output == '' then
    return {}
  end
  if output:sub(1, 1) ~= RECORD then
    return {
      status(context, 'invalid-report', 'Unexpected Perl::Critic output; inspect stderr and the installed version.'),
    }
  end
  ---@type vim.Diagnostic[]
  local diagnostics = {}
  local target = canonical(context.filename, context.cwd)
  local count = vim.api.nvim_buf_line_count(context.bufnr)
  local malformed, foreign, limited = false, false, false
  local records = 0
  for record in
    vim.gsplit(output:sub(2), RECORD, {
      plain = true,
    })
  do
    records = records + 1
    if records > LIMITS.records or #diagnostics >= LIMITS.diagnostics then
      limited = true
      break
    end
    local parts = vim.split(record, FIELD, { plain = true })
    local line = positive_integer(parts[1])
    local column = positive_integer(parts[2])
    local severity = positive_integer(parts[3])
    if
      #parts ~= 7
      or not line
      or not column
      or not severity
      or not SEVERITIES[severity]
      or not parts[4]:match('^Perl::Critic::Policy::[%w_:]+$')
      or parts[5] == ''
    then
      malformed = true
    elseif canonical(parts[7], root(context)) ~= target then
      foreign = true
    else
      ---@cast line integer
      ---@cast column integer
      ---@cast severity integer

      local item = status(context, parts[4]:gsub('^Perl::Critic::Policy::', ''), parts[5])

      item.lnum = math.min(line - 1, count - 1)
      item.severity = SEVERITIES[severity]

      local text = vim.api.nvim_buf_get_lines(context.bufnr, item.lnum, item.lnum + 1, false)[1] or ''
      local exact = line <= count and not text:find('[\t\128-\255]') and column <= #text + 1

      item.col = exact and column - 1 or 0

      item.end_lnum = item.lnum
      item.end_col = item.col
      if parts[6] ~= '' then
        item.message = clean(item.message .. ' — ' .. parts[6])
      end
      item.user_data = {
        filename = parts[7],
        reported_line = line,
        reported_column = column,
        perlcritic_severity = severity,
        position_exact = exact,
      }
      diagnostics[#diagnostics + 1] = item
    end
  end
  if malformed then
    diagnostics[#diagnostics + 1] =
      status(context, 'malformed-result', 'Some Perl::Critic records could not be parsed; inspect CLI output.')
  end
  if foreign then
    diagnostics[#diagnostics + 1] =
      status(context, 'other-files', 'Perl::Critic reported another file; those findings were not attached here.')
  end
  if limited then
    diagnostics[#diagnostics + 1] =
      status(context, 'result-limit', 'Perl::Critic reached the editor result limit; run the CLI for all findings.')
  end
  return diagnostics
end

---@type Linter
return {
  cmd = 'perlcritic',
  args = arguments,
  append_fname = false,
  automatic = true,
  cwd = root,
  env = {
    NO_COLOR = '1',
    PERLCRITIC = '',
    PERL5OPT = '',
  },
  exit_codes = { 0, 2 },
  ignore_exitcode = false,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = false,
  stream = 'stdout',
  timeout = 60000,
}
