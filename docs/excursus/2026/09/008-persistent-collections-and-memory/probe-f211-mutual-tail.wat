(wat.core/defn user/ev? [n :- wat.type/i64] :- wat.type/bool
  (wat.core/if (wat.core/= n 0) true (user/od? (wat.core/- n 1))))
(wat.core/defn user/od? [n :- wat.type/i64] :- wat.type/bool
  (wat.core/if (wat.core/= n 0) false (user/ev? (wat.core/- n 1))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/if (user/ev? 10000000) "even" "odd")))
