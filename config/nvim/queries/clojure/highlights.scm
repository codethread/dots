;; extends

; Split keyword literals so the `:`/`::` marker can be coloured on its own while
; the name inherits the (plain) `@string.special.symbol` default. Priority beats
; the whole-node capture from the upstream query.
(kwd_lit
  [":" "::"] @clojure.keyword.marker
  (#set! priority 105))

; A namespaced symbol (`s/def`, `str/blank?`) is one qualified reference. The LSP
; already paints the namespace alias; colour the `/` and name to match so the
; whole symbol reads as a unit. Priority beats the plain `@function.call` default.
(sym_lit
  namespace: (sym_ns)
  "/" @clojure.qualified.name
  name: (sym_name) @clojure.qualified.name
  (#set! priority 130))

; The namespace of a qualified keyword (`:foo/bar`) is data, not a type alias.
; clojure-lsp paints it with @lsp.type.type; override back to the plain keyword
; colour. Priority beats the semantic token (125).
(kwd_lit
  (kwd_ns) @clojure.keyword.namespace
  (#set! priority 130))

; A public `def`/`defn` name takes the function accent, so a var reads the same at
; its definition as at its call sites; private (`defn-`, `^:private`) and other
; def-like forms keep the definition colour. Priority beats clojure-lsp's semantic
; token (125), which does not distinguish public from private.
;
; The anchor before `name` forces it to be sym_lit's first child, which only holds
; when the symbol carries no `^…` reader metadata.
(list_lit
  .
  (sym_lit) @_def
  .
  (sym_lit
    .
    name: (sym_name) @clojure.def.public)
  (#any-of? @_def "def" "defn")
  (#set! priority 130))

; Metadata other than `^:private` (`^:dynamic`, `^String`, …) still leaves the var
; public. Map metadata (`^{:private true}`) is not matched and falls back to the
; definition colour.
(list_lit
  .
  (sym_lit) @_def
  .
  (sym_lit
    meta: (meta_lit
      value: (kwd_lit
        name: (kwd_name) @_meta))
    name: (sym_name) @clojure.def.public)
  (#any-of? @_def "def" "defn")
  (#not-eq? @_meta "private")
  (#set! priority 130))

; Docstrings: the string sitting right after the name in a def-form. Marked as
; documentation so it can read differently from ordinary strings.
(list_lit
  .
  (sym_lit) @_def
  .
  (sym_lit)
  .
  (str_lit) @string.documentation
  (#any-of? @_def
    "def" "defn" "defn-" "defmacro" "defmulti" "defprotocol" "definline" "defrecord"
    "deftype" "defonce" "ns")
  (#set! priority 105))
