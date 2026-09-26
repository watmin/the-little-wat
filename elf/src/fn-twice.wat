;; the same function's value, taken at two sites: one static object, not two
(wat.core/defn user/inc [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (user/inc 20))
    (wat.kernel/println ((wat.core/if true user/inc user/inc) 21))))
