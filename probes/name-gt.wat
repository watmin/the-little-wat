;; name-gt.wat: does a function name containing `>` lex? (The book's > is named o>.)
;; Expected if legal: true
(wat.core/defn u/o> [n :- wat.type/i64 m :- wat.type/i64] :- wat.type/bool
  (wat.core/> n m))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/o> 5 3)))
