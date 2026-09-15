;; lt-symbol.wat: J-Bob names <=len and totality/<, and uses < as an operator. F-008 found a
;; `<` in a *name* is a lex error. Inside quoted data? Expected (if fine): 3
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/length '(<=len totality/< <))))
