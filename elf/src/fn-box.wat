;; a function value stored in an aggregate, then called.
;; A pure record cannot hold a function type: the interpreter's containment rule
;; treats `[i64 :-> i64]` as an impure struct. An Impure enum is the aggregate
;; both sides accept.
(:wat::core::defenum :user::Hold :wat::enum::Impure
  :One [op <- [:wat::core::i64 :-> :wat::core::i64]])
(wat.core/defn user/inc [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [b (:user::Hold.One {:op user/inc})]
    (:wat::core::match b
      [:user::Hold.One {:op f} (wat.kernel/println (f 41))])))
