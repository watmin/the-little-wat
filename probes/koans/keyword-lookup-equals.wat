;; probes/koans/keyword-lookup-equals.wat: (:y m) answers an Option
;; (probes/koans/keyword-as-function.wat). Comparing it with a plain i64 is a type error; is it
;; refused by the checker in the keyword spelling, as (= 2 (Option.Some ...)) would be?

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::edn::write (:wat::core::= 2 (:y {:x 1 :y 2})))))
