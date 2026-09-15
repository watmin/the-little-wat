;; macro-arrow-user-steps.wat: the stdlib's own -> macro with user-fn steps, keyword-headed
;; and symbol-headed. Control for macro-arg-data-*.wat.
;; Expected: 8 then 8
(:wat::core::defn :u::add [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ a b))
(wat.core/defn u/dbl [a :- wat.type/i64] :- wat.type/i64 (wat.core/* a 2))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::core::-> 3 (:u::add 1) (:u::dbl)))
    (:wat::kernel::println (:wat::core::-> 3 (u/add 1) (u/dbl)))))
