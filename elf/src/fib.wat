(wat.core/defn user/fib [n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/< n 2)
    n
    (wat.core/+ (user/fib (wat.core/- n 1)) (user/fib (wat.core/- n 2)))))

(wat.core/defn user/fact [n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/<= n 1)
    1
    (wat.core/* n (user/fact (wat.core/- n 1)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/fib 20))
  (wat.kernel/println (user/fact 15))
  (wat.core/let [x (user/fib 10)]
    (wat.kernel/println (wat.core/+ x (user/fact 5)))))
