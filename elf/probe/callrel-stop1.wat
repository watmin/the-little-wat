;; STOP-1, empirically: a callee extends its LINEAR parameter while the caller still holds the
;; vector, the call returns i64 so the caller-side release rewinds r15 -- and then the heap is
;; churned hard enough that anything wrongly freed is overwritten before the caller reads it.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))

(wat.core/defn user/bump [v :- :user::Row] :- wat.type/i64
  (wat.core/nth (wat.core/conj v 99) 3))

(wat.core/defn user/churn [i :- wat.type/i64 n :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i n) acc
    (user/churn (wat.core/+ i 1) n
      (wat.core/+ acc (wat.core/nth (wat.core/Vector :- [wat.type/i64] 7 8 9 10 11 12) 5)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [base (wat.core/Vector :- [wat.type/i64] 10 20 30)
                 k    (user/bump base)
                 z    (user/churn 0 20000 0)]
    (wat.kernel/println k)                        ;; 99
    (wat.kernel/println z)                        ;; 240000
    (wat.kernel/println (wat.core/length base))   ;; 3, not 4
    (wat.kernel/println (wat.core/nth base 0))    ;; 10
    (wat.kernel/println (wat.core/nth base 1))    ;; 20
    (wat.kernel/println (wat.core/nth base 2))))  ;; 30
