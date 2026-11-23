; Adapted from void2610/tree-sitter-tyranoscript (MIT), 58aeff5620fbb8f1a2f7b9bd8534d8f29db210c6.
; タグの括弧
(tag "[" @punctuation.bracket)
(tag "]" @punctuation.bracket)

; @タグの@記号
(at_tag "@" @punctuation.special)

; タグ名
(tag_name) @function

; 制御フロー系タグ名はキーワードとして扱う
((tag_name) @keyword
 (#match? @keyword "^(if|elsif|else|endif|iscript|endscript|macro|endmacro|jump|call|return|s|for|endfor|while|endwhile|break|continue)$"))

; クリック待ち系タグ
((tag_name) @keyword
 (#match? @keyword "^(l|p|r|er|ct|cm|wd|wait)$"))

; 属性名
(attribute_name) @property

; 属性値
(quoted_string) @string
(unquoted_value) @string.special
(at_unquoted_value) @string.special

; 話者表示（#記号と話者名を同じ色に）
(speaker) @punctuation.special

; コメント
(comment) @comment

; ラベル
(label) @label
(label_name) @label

; テキスト行
(text_line) @operator

; インラインテキスト
(inline_text) @operator

; スクリプトブロックの開始・終了タグ
(script_block (iscript_open) @keyword)
(script_block (endscript_close) @keyword)
