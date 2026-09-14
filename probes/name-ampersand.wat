;; name-ampersand.wat: is `&` legal inside a name, as in the book's multirember&co? wat
;; uses a bare `&` as the rest-argument marker. Expected if legal: true
(wat.core/defn u/a&b [x :- wat.type/i64] :- wat.type/bool
  (wat.core/= x 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/a&b 1)))
