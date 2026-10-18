-- ~/.config/nvim/lua/formatters/awkfmt.lua
-- awkfmt formatter
---@module 'formatters.awkfmt'

---@source https://www.gnu.org/software/gawk/manual/html_node/Options.html

-- There is no tool named awkfmt: this catalogue key is bound to GNU
-- awk's own pretty-printer, the only AWK formatter that exists.
-- `gawk --pretty-print=- --file=-` reads the program text from stdin
-- (the `-` program file), prints the parsed program to stdout (the
-- `-` output file), and exits WITHOUT executing it — a system() call
-- or output redirection in the source can never fire, and the `-`
-- output name means no awkprof.out is ever written. A syntax error
-- exits 1 with nothing on stdout, so the runner rejects the stage
-- instead of publishing a partial format. The trailing `--` keeps
-- any later runner-appended operand from being read as an option.
--
-- What the dump does to a program (verified against gawk 5.4.1):
-- comments survive verbatim — a comment-only file is byte-identical
-- after formatting — string and regexp literals are reprinted
-- exactly, backslash line continuations are joined (the string value
-- is unchanged), and the output is a fixpoint that behaves
-- identically to the input when run. Three layout facts to know
-- before running it: indentation is tabs, function definitions move
-- after the rules, and a redirected print is parenthesised
-- (`print (expr) > file`, which gawk parses as that same redirection;
-- historical non-gawk awks may parse it as a comparison). A program
-- using @include is printed with the included text inlined, so
-- formatting such a file vendors its includes into the buffer.
--
-- allow_empty is safe here, not a loophole: any program containing a
-- single token — even a lone comment — produces output, so empty
-- output is reachable only from an empty or whitespace-only buffer.
-- The flag exists so a blank buffer formats to a blank buffer
-- instead of tripping the runner's empty-output guard.
---@type FormatterSpec
return {
    allow_empty = true,
    args = { '--pretty-print=-', '--file=-', '--' },
    automatic = true,
    cmd = 'gawk',
    cwd = nil,
    decode = nil,
    description = 'gawk pretty-printer: parses the program from stdin and prints it; never executes it',
    env = {},
    exit_codes = { 0 },
    extension = 'awk',
    filetypes = { 'awk' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
