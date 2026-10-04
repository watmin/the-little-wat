;; excursus 008 3b-3: one creation site, each closure capturing the previous one, 100,000
;; deep, made and dropped un-called, twenty times. A closure's glue is fixed per creation
;; site in BREADTH (what it captures) but not in DEPTH: this chain is as deep as the data.
(wat.core/defn user/step [f :- [wat.type/i64 :-> wat.type/i64]] :- [wat.type/i64 :-> wat.type/i64]
  (wat.core/fn [x :- wat.type/i64] :- wat.type/i64 (wat.core/+ (f x) 1)))

(wat.core/defn user/chain [i :- wat.type/i64 f :- [wat.type/i64 :-> wat.type/i64]] :- [wat.type/i64 :-> wat.type/i64]
  (wat.core/if (wat.core/= i 0) f (user/chain (wat.core/- i 1) (user/step f))))

(wat.core/defn user/one [s :- wat.type/String] :- wat.type/i64
  (wat.core/let [f (user/chain 100000 (wat.core/fn [x :- wat.type/i64] :- wat.type/i64 (wat.core/+ x (wat.string/length s))))]
    1))

(wat.core/defn user/rounds [r :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= r 0) acc
    (user/rounds (wat.core/- r 1) (wat.core/+ acc (user/one (wat.string/concat "s" (wat.i64/to-string r)))))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.i64/to-string (user/rounds 20 0))))
