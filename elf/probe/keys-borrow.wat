;; ORCHESTRATOR'S adversarial probe for 5b: a Vector read out of a record BY DESTRUCTURING, handed to
;; a function that conj's its linear parameter, then read back through the record. If the destructured
;; read is not counted, the callee grows the record's live vector in place (F-188's class).
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::defrecord :user::R [xs <- :user::Row k <- :wat::core::i64])
(wat.core/defn user/bump [v :- :user::Row] :- wat.type/i64
  (wat.core/length (wat.core/conj v 99)))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [r  (:user::R :xs (wat.core/Vector :- [wat.type/i64] 1 2 3) :k 7)
                 {:keys [xs]} r
                 n  (user/bump xs)]
    (wat.kernel/println n)                                    ;; 4
    (wat.kernel/println (wat.core/length (:user::R/xs r)))))  ;; 3 -- the record's vector untouched
