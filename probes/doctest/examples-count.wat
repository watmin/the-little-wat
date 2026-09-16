;; probes/doctest/examples-count.wat: the census alone, without running the doctests.
;;
;; probes/doctest/examples-census.wat called :wat::doctest::verify-examples and the RUNNER died
;; before a single count was printed. This asks only the reflection seam — how many @example
;; lines wat-rs exposes, and how they are marked — so the census survives whatever the runner
;; does.
;;
;; Run from the repository root: wat probes/doctest/examples-count.wat

(:wat::core::typealias :dc::Examples (:wat::core::Vector :- [:wat::intrinsic::Example]))

(:wat::core::defn :dc::count-where [exs <- :dc::Examples f <- [:wat::intrinsic::Example :-> :wat::core::bool]] -> :wat::core::i64
  (:wat::core::length (:wat::core::filterv f exs)))

(:wat::core::defn :dc::runnable? [e <- :wat::intrinsic::Example] -> :wat::core::bool
  (:wat::intrinsic::Example/run e))
(:wat::core::defn :dc::pure? [e <- :wat::intrinsic::Example] -> :wat::core::bool
  (:wat::intrinsic::Example/pure e))
(:wat::core::defn :dc::deterministic? [e <- :wat::intrinsic::Example] -> :wat::core::bool
  (:wat::intrinsic::Example/deterministic e))
(:wat::core::defn :dc::has-expected? [e <- :wat::intrinsic::Example] -> :wat::core::bool
  (:wat::core::match (:wat::intrinsic::Example/expected e)
    [:wat::core::Option.Some {:value _v} true]
    [:wat::core::Option.None {} false]))

(:wat::core::defn :dc::show [label <- :wat::core::String n <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " (:wat::i64::to-string n))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [exs (:wat::intrinsic::examples)]
    (:wat::core::do
      (:dc::show "examples reflected" (:wat::core::length exs))
      (:dc::show "  runnable (@example)" (:dc::count-where exs :dc::runnable?))
      (:dc::show "  declared pure" (:dc::count-where exs :dc::pure?))
      (:dc::show "  declared deterministic" (:dc::count-where exs :dc::deterministic?))
      (:dc::show "  carry an expected value" (:dc::count-where exs :dc::has-expected?))
      ;; the registry census, from the sibling seam
      (:dc::show "registry rows" (:wat::core::length (:wat::intrinsic::rows))))))
