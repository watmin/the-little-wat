;; probes/learner/f64-in-failure-record.wat: how does wat's own value renderer (the one in
;; a failure record) print an f64? A failing assert-eq runs in a thread; its record goes to
;; stderr with :actual and :expected.

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:wat::test::run-thread (:wat::test::assert-eq 100.0 1e21))
    [:wat::kernel::RunResult.Passed {} (:wat::kernel::println "passed?!")]
    [:wat::kernel::RunResult.Failed {:failure f} (:wat::kernel::println (:wat::kernel::Failure/message f))]))
