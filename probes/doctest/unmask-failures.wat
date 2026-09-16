;; probes/doctest/unmask-failures.wat: WHICH of wat's own documented examples fail, and why?
;;
;; wat-rs's NOTE (docs/arc/2026/06/296-diagnostics-fully-edn/
;; NOTE-the-doctest-runner-masks-every-failure-behind-one-raise.md) records that
;; :wat::doctest::verify-examples raises on the first non-comparable pair, escapes its own foldl,
;; and reports a raise instead of a Vector of Failures — "one bad example hides the result of
;; every other example". Of its second known instance it says:
;;
;;   "Instance 2's own source CANNOT BE IDENTIFIED while the mask is up — the runner reports the
;;    raise, not the example that caused it. That is the defect describing itself."
;;
;; It can be identified from outside, changing nothing in wat-rs.
;;
;; The NOTE's picture of the defect has THREE steps and marks the first two as safe:
;;
;;   (eval-ast! expr)      -> Ok | Err   "becomes a Failure"
;;   (eval-ast! expected)  -> Ok | Err   "becomes a Failure"
;;   (= got want)          -> UNGUARDED
;;
;; The first two ticks do not hold. A first attempt at this probe guarded only the comparison,
;; exactly as the NOTE's option (2) proposes, and still died — `eval-ast!` RAISED past its own
;; Result with "unreachable", from <intrinsic-example>. So evaluation is a third unguarded path,
;; and guarding the comparison alone would not have been enough.
;;
;; This guards the WHOLE per-example classification with :wat::test::run-thread and delivers the
;; verdict as the raise message, so every outcome — mismatch, eval failure, or a raise from any
;; stage — comes back as a value and the walk continues.
;;
;; The guard costs about 1.3 ms a catch (F-063), so 626 examples cost about a second. It lives in
;; the :wat::test:: namespace, which is why a substrate author writing wat/doctest.wat would not
;; reach for it — F-063's point exactly. Load order permits it: wat/test.wat is stdlib file #34,
;; wat/doctest.wat is #38.
;;
;; Run from the repository root: wat probes/doctest/unmask-failures.wat

(:wat::core::typealias :um::Examples (:wat::core::Vector :- [:wat::intrinsic::Example]))
(:wat::core::typealias :um::Lines (:wat::core::Vector :- [:wat::core::String]))

;; the verdict for one example, computed WITHOUT any guard — anything in here may raise
(:wat::core::defn :um::verdict [ex <- :wat::intrinsic::Example] -> :wat::core::String
  (:wat::core::match (:wat::intrinsic::Example/expected ex)
    [:wat::core::Option.None {} "no-expected"]
    [:wat::core::Option.Some {:value want-ast}
      (:wat::core::match (:wat::eval-ast! (:wat::intrinsic::Example/expr ex))
        [:wat::core::Result.Err {:error e} (:wat::string::concat "expr-err: " (:um::clip (:wat::edn::write e)))]
        [:wat::core::Result.Ok {:value got}
          (:wat::core::match (:wat::eval-ast! want-ast)
            [:wat::core::Result.Err {:error e} (:wat::string::concat "want-err: " (:um::clip (:wat::edn::write e)))]
            [:wat::core::Result.Ok {:value want}
              (:wat::core::if (:wat::core::= got want) "match" "mismatch")])])]))

(:wat::core::defn :um::clip [s <- :wat::core::String] -> :wat::core::String
  (:wat::core::let [n (:wat::string::length s)]
    (:wat::core::if (:wat::core::> n 150) (:wat::string::subs s 0 150) s)))

(:wat::core::defn :um::known? [m <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::string::starts-with? m "match")
    (:wat::core::or (:wat::string::starts-with? m "mismatch")
      (:wat::core::or (:wat::string::starts-with? m "expr-err")
        (:wat::core::or (:wat::string::starts-with? m "want-err") (:wat::string::starts-with? m "no-expected"))))))

;; the whole verdict, guarded: the answer is delivered as the raise message, so a REAL raise from
;; any stage arrives the same way and is simply not one of the known words.
(:wat::core::defn :um::classify [ex <- :wat::intrinsic::Example] -> :wat::core::String
  (:wat::core::if (:wat::core::not (:wat::intrinsic::Example/run ex))
    "skip"
    (:wat::core::match (:wat::test::run-thread
                         (:wat::kernel::assertion-failed! :message (:um::verdict ex)))
      [:wat::kernel::RunResult.Passed {} "impossible"]
      [:wat::kernel::RunResult.Failed {:failure f}
        (:wat::core::let [m (:wat::kernel::Failure/message f)]
          (:wat::core::if (:um::known? m) m (:wat::string::concat "raised: " m)))])))

(:wat::core::defn :um::fqdn [ex <- :wat::intrinsic::Example] -> :wat::core::String
  (:wat::edn::write (:wat::intrinsic::Example/fqdn ex)))

(:wat::core::defn :um::line [ex <- :wat::intrinsic::Example] -> :wat::core::String
  (:wat::string::concat (:um::classify ex) "  " (:um::fqdn ex)))

(:wat::core::defn :um::count-prefixed [lines <- :um::Lines p <- :wat::core::String] -> :wat::core::i64
  (:wat::core::length
    (:wat::core::filterv
      (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool (:wat::string::starts-with? s p))
      lines)))

(:wat::core::defn :um::show [label <- :wat::core::String n <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " (:wat::i64::to-string n))))

(:wat::core::defn :um::print-each [lines <- :um::Lines i <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::>= i n)
    nil
    (:wat::core::do
      (:wat::kernel::println (:wat::core::nth lines i))
      (:um::print-each lines (:wat::core::+ i 1) n))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [exs   (:wat::intrinsic::examples)
                    lines (:wat::core::mapv :um::line exs)
                    interesting (:wat::core::filterv
                                  (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool
                                    (:wat::core::and
                                      (:wat::core::not (:wat::string::starts-with? s "match"))
                                      (:wat::core::not (:wat::string::starts-with? s "skip"))))
                                  lines)]
    (:wat::core::do
      (:um::show "examples" (:wat::core::length exs))
      (:um::show "  match" (:um::count-prefixed lines "match"))
      (:um::show "  mismatch" (:um::count-prefixed lines "mismatch"))
      (:um::show "  RAISED past eval-ast!/=" (:um::count-prefixed lines "raised"))
      (:um::show "  expr-err" (:um::count-prefixed lines "expr-err"))
      (:um::show "  want-err" (:um::count-prefixed lines "want-err"))
      (:um::show "  skip (@example-norun)" (:um::count-prefixed lines "skip"))
      (:um::show "  no-expected" (:um::count-prefixed lines "no-expected"))
      (:wat::kernel::println "---- every example that is neither a match nor a skip ----")
      (:um::print-each interesting 0 (:wat::core::length interesting)))))
