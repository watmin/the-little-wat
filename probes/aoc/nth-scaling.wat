;; probes/aoc/nth-scaling.wat: is indexing a Vector with nth linear in the index?
;; aoc/day01-sonar.wat and aoc/day02-smoke.wat both loop over a Vector by index, which is the
;; shape a puzzle takes, and both cost more than the work suggests.
;;
;; This does one thing: build a Vector of n numbers, then read every element by nth, twice —
;; once at n and once at 2n. Doubling the time means nth is constant; quadrupling it means nth
;; walks to the index.
;;
;; Run from the repository root, timing each size:
;;   SIZE=20000 time wat probes/aoc/nth-scaling.wat
;; (the size is baked in below; the two sizes are two runs of the two functions)

(:wat::core::typealias :probe::Ints (:wat::core::Vector :- [:wat::core::i64]))

(:wat::core::defn :probe::grow [n <- :wat::core::i64 acc <- :probe::Ints] -> :probe::Ints
  (:wat::core::if (:wat::core::= n 0)
    acc
    (:probe::grow (:wat::core::- n 1) (:wat::core::conj acc n))))

(:wat::core::defn :probe::sum-by-index [xs <- :probe::Ints i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs))
    acc
    (:probe::sum-by-index xs (:wat::core::+ i 1) (:wat::core::+ acc (:wat::core::nth xs i)))))

;; the same reading, by walking the rest instead of by index
(:wat::core::defn :probe::sum-by-rest [xs <- :probe::Ints acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::empty? xs)
    acc
    (:probe::sum-by-rest (:wat::core::rest xs) (:wat::core::+ acc (:wat::core::first xs)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [xs (:probe::grow 20000 (:wat::core::Vector :- [:wat::core::i64]))
                    start-index (:wat::time::epoch-millis (:wat::time::now))
                    by-index (:probe::sum-by-index xs 0 0)
                    after-index (:wat::time::epoch-millis (:wat::time::now))
                    by-rest (:probe::sum-by-rest xs 0)
                    after-rest (:wat::time::epoch-millis (:wat::time::now))]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "20000 elements read by nth: "
                                                   (:wat::i64::to-string (:wat::core::- after-index start-index)) " ms"))
      (:wat::kernel::println (:wat::string::concat "20000 elements read by rest: "
                                                   (:wat::i64::to-string (:wat::core::- after-rest after-index)) " ms"))
      (:wat::test::assert-eq by-index by-rest))))
