; extends

; Parse multiline basic and literal strings as Bash.
((string) @injection.content
  (#match? @injection.content "^\"\"\"")
  (#offset! @injection.content 0 3 0 -3)
  (#set! injection.include-children)
  (#set! injection.language "bash"))

((string) @injection.content
  (#match? @injection.content "^'''")
  (#offset! @injection.content 0 3 0 -3)
  (#set! injection.include-children)
  (#set! injection.language "bash"))
