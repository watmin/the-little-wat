;; letrec-named-fn.wat: Clojure gets local recursion from a NAMED fn, (fn fact [n] ...),
;; whose name is bound inside its own body. Does wat accept that shape?
;; Expected if it works: 120. Otherwise, the checker's diagnostic is the finding.
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [fact (:wat::core::fn fact [n <- :wat::core::i64] -> :wat::core::i64
            (:wat::core::if (:wat::core::= n 0)
              1
              (:wat::core::* n (fact (:wat::core::- n 1)))))]
    (:wat::kernel::println (fact 5))))
