;; excursus 008 stone 3b: a closure that captures a String, made, called and dropped each round.
;; Its glue is its creation site's: the closure object does not say how many captures it has.
(wat.core/defn user/greeter [s :- wat.type/String] :- [wat.type/i64 :-> wat.type/i64]
  (wat.core/fn [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n (wat.string/length s))))

(wat.core/defn user/rounds [r :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= r 0) acc
    (user/rounds (wat.core/- r 1)
      (wat.core/+ acc ((user/greeter (wat.string/concat "hello-" (wat.i64/to-string r))) 1)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.i64/to-string (user/rounds 100000 0))))
