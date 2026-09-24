; extends

; Parse multiline basic and literal strings as Markdown.
((string) @injection.content
  (#match? @injection.content "^\"\"\"")
  (#offset! @injection.content 0 3 0 -3)
  (#set! injection.include-children)
  (#set! injection.language "markdown"))

((string) @injection.content
  (#match? @injection.content "^'''")
  (#offset! @injection.content 0 3 0 -3)
  (#set! injection.include-children)
  (#set! injection.language "markdown"))
