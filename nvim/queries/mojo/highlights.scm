; highlights.scm
; Qompass AI - [ ]
; Copyright (C) 2025 Qompass AI, All rights reserved
; ----------------------------------------
(attribute attribute: (identifier) @property)
(type (identifier) @type)
(decorator) @function
(decorator
  (identifier) @function)
(call
  function: (attribute attribute: (identifier) @function.method))
(call
  function: (identifier) @function)
(function_definition
  name: (identifier) @function)
((identifier) @type
 (#match? @type "^[A-Z]"))
((identifier) @constant
 (#match? @constant "^_*[A-Z][A-Z\\d_]*$"))
((call
  function: (identifier) @function.builtin)
 (#match?
   @function.builtin
   "^(abs|all|always_inline|any|ascii|bin|bool|breakpoint|bytearray|bytes|callable|chr|classmethod|compile|complex|constrained|delattr|dict|dir|divmod|enumerate|eval|exec|filter|float|format|frozenset|getattr|globals|hasattr|hash|help|hex|id|input|int|isinstance|issubclass|iter|len|list|locals|map|max|memoryview|min|next|object|oct|open|ord|pow|print|property|range|repr|reversed|round|set|setattr|slice|sorted|staticmethod|str|sum|super|tuple|type|unroll|vars|zip|__mlir_attr|__mlir_op|__mlir_type|__import__)$"))
[
  (none)
  (true)
  (false)
] @constant.builtin
[
  (integer)
  (float)
] @number
(comment) @comment
(string) @string
(escape_sequence) @escape
[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket
(interpolation
  "{" @punctuation.special
  "}" @punctuation.special) @embedded
(function_definition
  "async"?
  "def"
  name: (_)
  (parameters)?
  body: (block (expression_statement (string) @string.doc)))
[
  "-"
  "-="
  "!="
  "*"
  "**"
  "**="
  "*="
  "/"
  "//"
  "//="
  "/="
  "&"
  "%"
  "%="
  "^"
  "+"
  "->"
  "+="
  "<"
  "<<"
  "<="
  "<>"
  "="
  ":="
  "=="
  ">"
  ">="
  ">>"
  "|"
  "~"
  "and"
  "in"
  "is"
  "not"
  "or"
  "is not"
  "not in"
  "!"
] @operator
[
  "as"
  "comptime"
  "assert"
  "async"
  "await"
  "borrowed"
  "break"
  "capturing"
  "class"
  "continue"
  "def"
  "del"
  "deinit"
  "elif"
  "else"
  "escaping"
  "except"
  "exec"
  "finally"
  "fn"
  "for"
  "from"
  "global"
  "if"
  "import"
  "inout"
  "lambda"
  "nonlocal"
  "owned"
  "out"
  "pass"
  "print"
  "raise"
  "raises"
  "ref"
  "return"
  "struct"
  "trait"
  "try"
  "var"
  "while"
  "with"
  "yield"
  "match"
  "case"
  "where"
] @keyword
(mlir_type "!" @punctuation.special (#set! "priority" 110))
(mlir_type ">" @punctuation.special (#set! "priority" 110))
(mlir_type "<" @punctuation.special (#set! "priority" 110))
(mlir_type "->" @punctuation.special (#set! "priority" 110))
(mlir_type "(" @punctuation.special (#set! "priority" 110))
(mlir_type ")" @punctuation.special (#set! "priority" 110))
(mlir_type "." @punctuation.special (#set! "priority" 110))
(mlir_type ":" @punctuation.special (#set! "priority" 110))
(mlir_type "+" @punctuation.special (#set! "priority" 110))
(mlir_type "-" @punctuation.special (#set! "priority" 110))
(mlir_type "*" @punctuation.special (#set! "priority" 110))
(mlir_type "," @punctuation (#set! "priority" 110))
(mlir_type) @type
; (argument_convention) @keyword