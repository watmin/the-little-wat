(wat.core/defn user/fib [n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/< n 2)
    n
    (wat.core/+ (user/fib (wat.core/- n 1)) (user/fib (wat.core/- n 2)))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/fib 27)))
