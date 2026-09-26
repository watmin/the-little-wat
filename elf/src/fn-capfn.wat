;; a closure captures another closure, and calls a top-level function. The top-level name is
;; not a capture. Interpreter: 23.
(wat.core/defn user/inc [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [f (wat.core/fn [k :- wat.type/i64] :- wat.type/i64 (wat.core/+ k 2))
                 g (wat.core/fn [n :- wat.type/i64] :- wat.type/i64
                     (wat.core/+ (user/inc n) (f n)))]
    (wat.kernel/println (g 10))))
