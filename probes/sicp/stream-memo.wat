;; probes/sicp/stream-memo.wat: does forcing a lazy stream remember what it computed? SICP §3.5
;; turns on it: delay memoizes, so walking a stream twice computes each element once. In guile,
;; with the same code as oracle/sicp/ch35-streams.scm, walking the first five elements of
;; (stream-map counted integers), then the same five again, then seven, counts 6, 6 and 8
;; computations.
;;
;; Here the same walk, over one stream value, counting each computation with a counter service.
;;
;; Run from the repository root: wat probes/sicp/stream-memo.wat

(:wat::load-file! "../../books/seasoned-schemer/lib/counter.wat")

(:wat::core::typealias :probe::IntStream (:wat::stream::Stream :- [:wat::core::i64]))

(:wat::core::defn :probe::integers-from [n <- :wat::core::i64] -> :probe::IntStream
  (:wat::stream::cons n (:wat::stream::lazy (:probe::integers-from (:wat::core::+ n 1)))))

(:wat::core::defn :probe::smap [f <- [:wat::core::i64 :-> :wat::core::i64] s <- :probe::IntStream] -> :probe::IntStream
  (:wat::stream::lazy
    (:wat::core::match (:wat::stream::next s)
      [:wat::stream::NextOutcome.Exhausted {} (:wat::stream::empty)]
      [:wat::stream::NextOutcome.Item {:value v :rest r} (:wat::stream::cons (f v) (:probe::smap f r))])))

(:wat::core::defn :probe::walk [s <- :probe::IntStream n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0)
    0
    (:wat::core::match (:wat::stream::next s)
      [:wat::stream::NextOutcome.Exhausted {} 0]
      [:wat::stream::NextOutcome.Item {:value v :rest r} (:wat::core::+ v (:probe::walk r (:wat::core::- n 1)))])))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [c (:ss::new-counter 0)
                    counted (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64
                              (:wat::core::do (:ss::counter-add! c 1) n))
                    s (:probe::smap counted (:probe::integers-from 1))]
    (:wat::core::do
      (:probe::walk s 5)
      (:wat::kernel::println (:wat::string::concat "after five: " (:wat::i64::to-string (:ss::counter-get c)) " computed (guile: 6)"))
      (:probe::walk s 5)
      (:wat::kernel::println (:wat::string::concat "after the same five again: " (:wat::i64::to-string (:ss::counter-get c)) " computed (guile: 6)"))
      (:probe::walk s 7)
      (:wat::kernel::println (:wat::string::concat "after seven: " (:wat::i64::to-string (:ss::counter-get c)) " computed (guile: 8)")))))
