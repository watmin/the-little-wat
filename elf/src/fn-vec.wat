;; a closure captures a Vector and conjs it. The original keeps its length.
;; Interpreter: 2, 3, 2.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [v (wat.core/Vector :- [wat.type/i64] 1 2)
                 f (wat.core/fn [] :- wat.type/i64
                     (wat.core/length (wat.core/conj v 3)))]
    (wat.kernel/println (wat.core/length v))
    (wat.kernel/println (f))
    (wat.kernel/println (wat.core/length v))))
