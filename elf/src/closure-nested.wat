;; CLOSURE FIXTURE (2026-09-24): closures RETURNED from functions, a closure over two closures, and a
;; closure over that closure. Interpreter: 16 then 27. Known answers for the closure stone.
;; adder RETURNS a closure capturing k
(wat.core/defn user/adder [k :- wat.type/i64] :- [wat.type/i64 :-> wat.type/i64]
  (wat.core/fn [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n k)))

;; compose RETURNS a closure capturing TWO closures
(wat.core/defn user/compose [f :- [wat.type/i64 :-> wat.type/i64]
                             g :- [wat.type/i64 :-> wat.type/i64]] :- [wat.type/i64 :-> wat.type/i64]
  (wat.core/fn [n :- wat.type/i64] :- wat.type/i64 (f (g n))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [add1  (user/adder 1)
                 add10 (user/adder 10)
                 both  (user/compose add1 add10)        ;; a closure over closures over k=1 and k=10
                 twice (user/compose both both)]        ;; ...and a closure over THAT, twice
    (wat.kernel/println (both 5))                       ;; 5 + 10 + 1       = 16
    (wat.kernel/println (twice 5))))                    ;; 5 + 11 + 11      = 27
