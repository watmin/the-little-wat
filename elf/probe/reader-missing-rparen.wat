;; F-205. One `)` too few. wat: UnclosedParen. The native compiler ACCEPTED it and printed 3. Must be
;; refused at compile time, naming where the unclosed `(` opened.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/+ 1 2))
