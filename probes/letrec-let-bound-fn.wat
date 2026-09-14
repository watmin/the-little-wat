;; letrec-let-bound-fn.wat: can a fn bound in a let refer to its own binding (local
;; self-recursion, the job letrec does)? ITERATION-PATTERNS.md says no.
;; Expected per that doc: a startup error naming the unresolved self-reference.
;; Expected if it works: 120.
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [fact (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64
            (:wat::core::if (:wat::core::= n 0)
              1
              (:wat::core::* n (fact (:wat::core::- n 1)))))]
    (:wat::kernel::println (fact 5))))
