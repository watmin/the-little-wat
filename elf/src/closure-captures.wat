;; CLOSURE FIXTURE (2026-09-24), from the builder's own example: a fn capturing a value, a fn handed a
;; function, a fn capturing a CLOSURE. Interpreter: 126 then 86. The native compiler refuses `fn`
;; today; these are the known answers for the closure stone.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [x 42
                 ;; f captures a VALUE
                 f  (wat.core/fn [a :- wat.type/i64] :- wat.type/i64 (wat.core/+ a x))
                 ;; g captures x, and is HANDED a function
                 g  (wat.core/fn [b :- wat.type/i64 f' :- [wat.type/i64 :-> wat.type/i64]] :- wat.type/i64
                      (wat.core/+ x (f' b)))
                 ;; h captures a CLOSURE directly -- f -- no parameter needed
                 h  (wat.core/fn [c :- wat.type/i64] :- wat.type/i64 (wat.core/* 2 (f c)))]
    (wat.kernel/println (g x f))     ;; 42 + f(42) = 42 + 84      = 126
    (wat.kernel/println (h 1))))     ;; 2 * f(1)   = 2 * 43       = 86
