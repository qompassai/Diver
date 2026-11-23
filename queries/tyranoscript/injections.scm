; Adapted from void2610/tree-sitter-tyranoscript (MIT), 58aeff5620fbb8f1a2f7b9bd8534d8f29db210c6.
((comment) @injection.content
  (#set! "injection.language" "comment"))

; [iscript]...[endscript] 内をJavaScriptとしてハイライト
((script_block
  (script_content) @injection.content)
 (#set! "injection.language" "javascript"))

; []タグの exp/cond 属性値をJavaScriptとしてハイライト
((attribute
  name: (attribute_name) @_attr_name
  value: (attribute_value
    (quoted_string
      (string_content) @injection.content)))
 (#match? @_attr_name "^\\s*(exp|cond)$")
 (#set! "injection.language" "javascript"))

; @タグの exp/cond 属性値をJavaScriptとしてハイライト
((at_attribute
  name: (attribute_name) @_attr_name
  value: (at_attribute_value
    (quoted_string
      (string_content) @injection.content)))
 (#match? @_attr_name "^\\s*(exp|cond)$")
 (#set! "injection.language" "javascript"))
