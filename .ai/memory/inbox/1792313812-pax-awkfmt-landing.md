# awkfmt adapter landing (2026-10-18)

Landed lua/formatters/awkfmt.lua + its CHANGELOG section from the live
tree on Owner's ruling, closing the dangling catalogue key left by the
2026-09-25 formatter expansion (T9 had stopped: no tool named awkfmt
exists). The adapter binds the key to gawk's own pretty-printer
(`gawk --pretty-print=- --file=- --`): parse-only, never executes;
invalid input exits 1 with zero stdout and the buffer untouched.
Documented layout facts live in the adapter header (tab indentation,
function defs after rules, parenthesised redirected print, @include
inlined by gawk). Gates on the landed tree: LuaLS 0 (VIMRUNTIME set),
StyLua canonical clean, luacheck 0/0, journal workflow suite 208/208.
The live registry M.validate() reported 0 errors with the adapter in
place (worker-verified pre-landing).
