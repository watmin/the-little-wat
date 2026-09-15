;; probes/learner/i64-overflow.wat: what does i64 arithmetic do past its range? A
;; hand-written random number generator depends on it (there are no bit operations).

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [big 9223372036854775807]
    (:wat::core::do
      (:wat::kernel::println (:wat::i64::to-string big))
      (:wat::kernel::println (:wat::i64::to-string (:wat::core::+ big 1)))
      (:wat::kernel::println "after the overflow"))))
