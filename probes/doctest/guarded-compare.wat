;; probes/doctest/guarded-compare.wat: can a raise from `=` be caught per-comparison?
;;
;; wat-rs's own NOTE (docs/arc/2026/06/296-diagnostics-fully-edn/
;; NOTE-the-doctest-runner-masks-every-failure-behind-one-raise.md) says the doctest runner's
;; unguarded `(:wat::core::= got want)` raises on a non-comparable pair, escapes the foldl, and
;; masks every other example. It lists three candidate fixes and says of the second:
;;
;;   "Or: should the runner guard its own comparison — catching the raise per example and
;;    recording it as a Failure? That needs A RAISE-CATCHING MECHANISM THE RUNNER DOES NOT
;;    CURRENTLY HAVE; eval-ast! is the only guard available and it takes an AST, while the
;;    runner holds VALUES."
;;
;; and then: "(2) is the only one that fixes the masking rather than the instances".
;;
;; But wat HAS a raise-catching mechanism that takes an expression over values:
;; :wat::test::run-thread, which hands a death back as RunResult.Failed {:failure f} with a
;; readable message. books/little-typer/lib/pie.wat uses it for all 108 of Pie's refusals, and
;; F-063 measured it at about 1.3 ms a catch — 485 runnable examples would cost under a second.
;;
;; It lives in the :wat::test:: namespace, which is exactly F-063's complaint: wat's only general
;; catch is a TEST verb, so a substrate author writing wat/doctest.wat would not think to reach
;; for it.
;;
;; Three things measured here, smallest first:
;;   1. can an ordinary program call :wat::eval-ast! at all?
;;   2. does a run-thread-guarded comparison of a COMPARABLE pair report Passed?
;;   3. does a run-thread-guarded comparison of a NON-comparable pair — an Enum against a
;;      keyword, the exact shape that kills the real runner — come back as a VALUE with a
;;      message, instead of escaping?
;;
;; Run from the repository root: wat probes/doctest/guarded-compare.wat

(:wat::core::defn :gc::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

;; the guard the NOTE says does not exist: compare two values, catching a raise as a value
(:wat::core::defn :gc::guarded-equal [got <- :wat::core::Value want <- :wat::core::Value] -> :wat::core::String
  (:wat::core::match (:wat::test::run-thread
                       (:wat::core::if (:wat::core::= got want)
                         nil
                         (:wat::kernel::assertion-failed! :message "MISMATCH")))
    [:wat::kernel::RunResult.Passed {} "match"]
    [:wat::kernel::RunResult.Failed {:failure f}
      (:wat::core::let [m (:wat::kernel::Failure/message f)]
        (:wat::core::if (:wat::core::= m "MISMATCH")
          "mismatch (a real doctest failure)"
          (:wat::string::concat "RAISED, caught: " m)))]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; 1. can user code evaluate an AST?
    (:gc::show "eval-ast! (+ 1 2)"
      (:wat::core::match (:wat::eval-ast! (:wat::core::quote (:wat::core::+ 1 2)))
        [:wat::core::Result.Ok {:value v} (:wat::edn::write v)]
        [:wat::core::Result.Err {:error _e} "Err"]))

    ;; 2. a comparable pair, guarded — equal, and unequal
    (:gc::show "guarded 1 = 1" (:gc::guarded-equal 1 1))
    (:gc::show "guarded 1 = 2" (:gc::guarded-equal 1 2))

    ;; 3. the pair that kills the real runner: an Enum against a keyword
    (:gc::show "guarded Validation.Valid = :wat::edn::Validation::Valid"
      (:gc::guarded-equal (:wat::edn::validate 42 :wat::core::i64)
                          :wat::edn::Validation::Valid))))
