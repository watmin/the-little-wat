;; probes/doctest/examples-census.wat: do wat's OWN documented examples hold?
;;
;; wat-rs reflects every `@example` in its source through :wat::intrinsic::examples into typed
;; Example records (fqdn, expr, expected, run, pure, deterministic), and :wat::doctest::
;; verify-examples runs them all and answers a Vector of Failures. There are 692 @example lines
;; in wat-rs/src.
;;
;; That makes the documentation EXECUTABLE, and this repository's recurring finding is that
;; documentation and code drift apart (F-065: a 134-verb rete documented nowhere; the user
;; guide's retired verb names; the cheatsheet's `first` returning an Option). So: 692 claims the
;; docs make, checked at once, from an ordinary program rather than from wat-rs's harness.
;;
;; This first pass only COUNTS — how many examples exist, how many are marked runnable
;; (@example vs @example-norun), and how many fail. Rendering what failed needs the Failure
;; record's shape and comes next.
;;
;; Run from the repository root: wat probes/doctest/examples-census.wat

(:wat::core::typealias :dt::Examples (:wat::core::Vector :- [:wat::intrinsic::Example]))

(:wat::core::defn :dt::count-where [exs <- :dt::Examples f <- [:wat::intrinsic::Example :-> :wat::core::bool]] -> :wat::core::i64
  (:wat::core::length (:wat::core::filterv f exs)))

(:wat::core::defn :dt::runnable? [e <- :wat::intrinsic::Example] -> :wat::core::bool
  (:wat::intrinsic::Example/run e))

(:wat::core::defn :dt::pure? [e <- :wat::intrinsic::Example] -> :wat::core::bool
  (:wat::intrinsic::Example/pure e))

(:wat::core::defn :dt::deterministic? [e <- :wat::intrinsic::Example] -> :wat::core::bool
  (:wat::intrinsic::Example/deterministic e))

(:wat::core::defn :dt::show [label <- :wat::core::String n <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " (:wat::i64::to-string n))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [exs   (:wat::intrinsic::examples)
                    fails (:wat::doctest::verify-examples)]
    (:wat::core::do
      (:dt::show "examples reflected" (:wat::core::length exs))
      (:dt::show "  marked runnable (@example)" (:dt::count-where exs :dt::runnable?))
      (:dt::show "  declared pure" (:dt::count-where exs :dt::pure?))
      (:dt::show "  declared deterministic" (:dt::count-where exs :dt::deterministic?))
      (:dt::show "FAILURES" (:wat::core::length fails)))))
