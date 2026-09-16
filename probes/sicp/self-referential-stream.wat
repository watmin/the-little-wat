;; probes/sicp/self-referential-stream.wat: SICP §3.5 defines the Fibonacci stream by referring
;; to the stream being defined:
;;
;;   (define fibs (cons-stream 0 (cons-stream 1 (add-streams (stream-cdr fibs) fibs))))
;;
;; Only the delay makes that honest: nothing is forced until something is asked for. Can a wat
;; definition name itself inside a lazy body? (sicp/ch35-streams.wat writes fibs as a function
;; of its two seeds instead.)
;;
;; Run from the repository root: wat probes/sicp/self-referential-stream.wat

(:wat::core::typealias :probe::IntStream (:wat::stream::Stream :- [:wat::core::i64]))

(:wat::core::defn :probe::smap2 [a <- :probe::IntStream b <- :probe::IntStream] -> :probe::IntStream
  (:wat::stream::lazy
    (:wat::core::match (:wat::stream::next a)
      [:wat::stream::NextOutcome.Exhausted {} (:wat::stream::empty)]
      [:wat::stream::NextOutcome.Item {:value x :rest ra}
        (:wat::core::match (:wat::stream::next b)
          [:wat::stream::NextOutcome.Exhausted {} (:wat::stream::empty)]
          [:wat::stream::NextOutcome.Item {:value y :rest rb} (:wat::stream::cons (:wat::core::+ x y) (:probe::smap2 ra rb))])])))

(:wat::core::defn :probe::rest-of [s <- :probe::IntStream] -> :probe::IntStream
  (:wat::core::match (:wat::stream::next s)
    [:wat::stream::NextOutcome.Exhausted {} (:wat::stream::empty)]
    [:wat::stream::NextOutcome.Item {:value v :rest r} r]))

;; the definition that names itself
(:wat::core::def :probe::fibs
  (:wat::stream::cons 0
    (:wat::stream::cons 1
      (:wat::stream::lazy (:probe::smap2 (:probe::rest-of :probe::fibs) :probe::fibs)))))

(:wat::core::defn :probe::head [s <- :probe::IntStream n <- :wat::core::i64 acc <- (:wat::core::Vector :- [:wat::core::i64])] -> (:wat::core::Vector :- [:wat::core::i64])
  (:wat::core::if (:wat::core::= n 0)
    acc
    (:wat::core::match (:wat::stream::next s)
      [:wat::stream::NextOutcome.Exhausted {} acc]
      [:wat::stream::NextOutcome.Item {:value v :rest r} (:probe::head r (:wat::core::- n 1) (:wat::core::conj acc v))])))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::edn::write (:probe::head :probe::fibs 10 (:wat::core::Vector :- [:wat::core::i64])))))
