(bare_key) @property

(quoted_key) @string

; Markdown supplies the highlighting inside multiline strings. Leaving the
; containing TOML string uncaptured also keeps plain Markdown prose at Normal.
((string) @string
  (#not-match? @string "^\"\"\"")
  (#not-match? @string "^'''"))

(boolean) @boolean

(comment) @comment @spell

(escape_sequence) @string.escape

(integer) @number

(float) @number.float

[
  (local_date)
  (local_date_time)
  (local_time)
  (offset_date_time)
] @string.special

"=" @operator

[
  "."
  ","
] @punctuation.delimiter

[
  "["
  "]"
  "[["
  "]]"
  "{"
  "}"
] @punctuation.bracket

; Highlight packages in Cargo.toml.
(table (pair (bare_key) @boolean))
