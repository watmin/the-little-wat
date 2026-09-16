;; probes/err/error-in-stream.wat: when does an error inside a lazy stream happen, and how often?
;;
;; :wat::stream::lazy captures without evaluating, and F-053 says a forced stream does not
;; remember what it forced — walking one twice computes it twice. Put a failure inside one and
;; two questions follow, neither of which any suite here has asked:
;;
;;   1. does the error surface when the stream is BUILT, or when it is FORCED? A stream built in
;;      one place and forced in another moves the failure away from its cause, which is the
;;      hardest kind of bug to locate.
;;   2. since nothing is memoised, does a caught failure come back EVERY time the stream is
;;      walked? A program that recovers once and walks again would then fail again, having
;;      already handled it.
;;
;; The failure is caught with :wat::test::run-thread, which is the only general catch wat has.
;; If "built" prints before "forced", the answer to 1 is "forced".
;;
;; Run from the repository root: wat probes/err/error-in-stream.wat

(:wat::core::typealias :probe::S (:wat::stream::Stream :- [:wat::core::i64]))

(:wat::core::defn :probe::dies [] -> :wat::core::i64
  (:wat::kernel::assertion-failed! :message "probe: expected failure"))

;; a stream whose second element fails
(:wat::core::defn :probe::bad-stream [] -> :probe::S
  (:wat::stream::cons 1 (:wat::stream::lazy (:wat::stream::cons (:probe::dies) (:wat::stream::empty :- [:wat::core::i64])))))

;; force one step past the head, catching whatever happens
(:wat::core::defn :probe::force-second [s <- :probe::S] -> :wat::core::String
  (:wat::core::match (:wat::test::run-thread
                       (:wat::core::match (:wat::stream::next s)
                         [:wat::stream::NextOutcome.Item {:value v :rest r}
                           (:wat::core::match (:wat::stream::next r)
                             [:wat::stream::NextOutcome.Item {:value v2 :rest r2} nil]
                             [:wat::stream::NextOutcome.Exhausted {} nil])]
                         [:wat::stream::NextOutcome.Exhausted {} nil]))
    [:wat::kernel::RunResult.Passed {} "no failure"]
    [:wat::kernel::RunResult.Failed {:failure f} (:wat::string::concat "failed: " (:wat::kernel::Failure/message f))]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [s (:probe::bad-stream)]
    (:wat::core::do
      ;; if this prints, building the stream did not raise: the failure waits for the force
      (:wat::kernel::println "built the stream without dying")
      (:wat::kernel::println (:wat::string::concat "first walk: " (:probe::force-second s)))
      ;; F-053 says nothing is remembered — so does the same stream fail again?
      (:wat::kernel::println (:wat::string::concat "second walk: " (:probe::force-second s))))))
