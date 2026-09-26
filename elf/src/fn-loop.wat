;; a closure built on each trip of a loop, each capturing that trip's values.
;; 1+0, then 2+1, then 3+3: 6.
(wat.core/defn user/go [i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/> i 3) acc
    (wat.core/let [f (wat.core/fn [] :- wat.type/i64 (wat.core/+ acc i))]
      (user/go (wat.core/+ i 1) (f)))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/go 1 0)))
