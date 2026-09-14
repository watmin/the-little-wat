;; name-lt.wat: does a function name containing `<` lex? (The book's < is named o<.)
;; Clojure allows `<` in symbols. This is also a single-file program, so the check is
;; whether the lex error names this file.
;; Expected if legal: true
(wat.core/defn u/o< [n :- wat.type/i64 m :- wat.type/i64] :- wat.type/bool
  (wat.core/< n m))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/o< 3 5)))
