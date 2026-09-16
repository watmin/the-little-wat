;; probes/holon/coincident-semantics.wat: what do presence? and coincident? actually test?
;;
;; Both predicates are documented in terms of a "floor", and both floors are computed the same
;; way in wat-rs (src/vm_registry.rs): sigma / sqrt(dimensions). At the ambient d = 10000 that
;; gives presence-floor 0.49 (sigma 49) and coincident-floor 0.01 (sigma 1).
;;
;; But they USE those floors in opposite directions (src/holon/coincident.rs):
;;
;;   presence?     cosine > presence_floor                 -> cosine > 0.49   (a loose test)
;;   coincident?   (1.0 - cosine) < coincident_floor       -> cosine > 0.99   (a tight test)
;;
;; The documentation for coincident? says "whether `a`'s cosine to `b` clears the coincident
;; floor", which describes the FIRST shape, not the second. Read that way, a floor of 0.01 sounds
;; permissive — nearly anything clears 0.01 — when the real test admits only near-identity.
;;
;; This measures the ladder directly. Each bind/unbind round multiplies cosine by ~0.818, so the
;; rungs are ~1.0, 0.818, 0.667, 0.543 — all far above the stated 0.01 floor, and all rejected.
;;
;; coincident-explain reports `min-sigma-to-pass`, which confirms the formula arithmetically:
;; solving 1 - sigma*floor <= cosine gives 19 for the 0.818 rung and 101 for an orthogonal pair,
;; and those are exactly the numbers it reports.
;;
;; Run from the repository root: wat probes/holon/coincident-semantics.wat

(:wat::core::defn :cs::yn [b <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if b "yes" "NO"))

(:wat::core::defn :cs::cos [a <- :wat::holon::Vector b <- :wat::holon::Vector] -> :wat::core::String
  (:wat::core::match (:wat::holon::cosine a b)
    [:wat::holon::CosineOutcome.Similarity {:similarity s} (:wat::f64::to-string s)]
    [:wat::holon::CosineOutcome.Degenerate {:side _s} "DEGENERATE"]
    [:wat::holon::CosineOutcome.DimensionMismatch {:expected _e :got _g} "DIM"]))

(:wat::core::defn :cs::combined [o <- :wat::holon::CombineOutcome] -> :wat::holon::Vector
  (:wat::core::match o
    [:wat::holon::CombineOutcome.Combined {:vector v} v]
    [:wat::holon::CombineOutcome.DimensionMismatch {:expected _e :got _g}
      (:wat::kernel::assertion-failed! :message "dim")]))

(:wat::core::defn :cs::bind [a <- :wat::holon::Vector b <- :wat::holon::Vector] -> :wat::holon::Vector
  (:cs::combined (:wat::holon::vector-bind a b)))

(:wat::core::defn :cs::atom [n <- :wat::core::String] -> :wat::holon::Vector
  (:wat::holon::encode (:wat::holon::leaf n)))

(:wat::core::defn :cs::round [v <- :wat::holon::Vector k <- :wat::holon::Vector] -> :wat::holon::Vector
  (:cs::bind (:cs::bind v k) k))

(:wat::core::defn :cs::rung [label <- :wat::core::String v <- :wat::holon::Vector a <- :wat::holon::Vector] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label "  cos " (:cs::cos v a)
                          "  coincident? " (:cs::yn (:wat::holon::coincident? v a))
                          "  " (:wat::edn::write (:wat::holon::coincident-explain v a)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [a (:cs::atom "alpha") b (:cs::atom "beta")
                    c (:cs::atom "gamma") d (:cs::atom "delta")
                    la (:wat::holon::leaf "alpha") lb (:wat::holon::leaf "beta")
                    r1 (:cs::round a b)
                    r2 (:cs::round r1 c)
                    r3 (:cs::round r2 d)]
    (:wat::core::do
      (:wat::kernel::println "-- the ladder: every rung is far above the stated 0.01 floor --")
      (:cs::rung "0 rounds" a  a)
      (:cs::rung "1 round " r1 a)
      (:cs::rung "2 rounds" r2 a)
      (:cs::rung "3 rounds" r3 a)
      (:wat::kernel::println "-- the two floors, same formula sigma/sqrt(d), opposite use --")
      (:wat::kernel::println
        (:wat::string::concat "presence-floor @10000 = "
          (:wat::f64::to-string (:wat::holon::presence-floor 10000))
          "   coincident-floor @10000 = "
          (:wat::f64::to-string (:wat::holon::coincident-floor 10000))))
      (:wat::kernel::println "-- presence? takes HolonAST only; these are the ONLY calls it accepts --")
      (:wat::kernel::println
        (:wat::string::concat "presence?(leaf alpha, leaf alpha) " (:cs::yn (:wat::holon::presence? la la))
                              "   presence?(leaf alpha, leaf beta) " (:cs::yn (:wat::holon::presence? la lb))))
      (:wat::kernel::println
        "NOTE: (:wat::holon::presence? <Vector> <Vector>) is REFUSED AT STARTUP — parameter #1 expects :wat::holon::HolonAST"))))
