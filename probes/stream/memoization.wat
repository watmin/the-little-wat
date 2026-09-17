;; probes/stream/memoization.wat: does a lazy stream remember what it forced?
;;
;; F-053 records "a stream that remembers what it forced" as missing. This measures it, and names
;; the consequence: Okasaki's entire Part II -- every amortized-to-worst-case transformation in
;; chapters 6 through 11 -- depends on a suspension being forced AT MOST ONCE and shared
;; thereafter. That is what lazy evaluation buys in a persistent setting; without it the
;; transformations do not merely lose their bounds, they have no mechanism at all.
;;
;; The suspension below prints when it runs, so forcing is visible. The SAME stream value is
;; forced three times.
;;
;; Expected: FORCED three times, and all three answers equal -- correct, and recomputed.
;;
;; Note the calling convention: :wat::stream::lazy takes a BODY EXPRESSION, not a thunk. Passing
;; `(fn [] -> ...)` is refused -- "expects (wat::stream::Stream :- [T]); got [:-> ...]".
;;
;; Run: wat probes/stream/memoization.wat

(:wat::core::defn :sm::mk [] -> (:wat::stream::Stream :- [:wat::core::i64])
  (:wat::stream::lazy
    (:wat::core::do
      (:wat::kernel::println "FORCED")
      (:wat::stream::cons 1 (:wat::stream::empty)))))

(:wat::core::defn :sm::head [s <- (:wat::stream::Stream :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::match (:wat::stream::next s)
    [:wat::stream::NextOutcome.Item {:value v :rest r} v]
    [:wat::stream::NextOutcome.Exhausted {} -1]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [s (:sm::mk) a (:sm::head s) b (:sm::head s) c (:sm::head s)]
    (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
      "three forces of ONE stream -> " (:wat::i64::to-string a) (:wat::i64::to-string b) (:wat::i64::to-string c)
      "  (lines above: 3 means recomputed, 1 would mean memoized)")))))
