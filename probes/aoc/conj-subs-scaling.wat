;; probes/aoc/conj-subs-scaling.wat: how do growing a Vector and taking one-character substrings
;; scale? Reading a puzzle's input does both: every line parsed is one conj onto the growing
;; Vector (F-023 says conj clones), and every digit of a grid is one subs.
;;
;; Each is timed at n and at 2n, in one run, with wat's own clock. Doubling means linear;
;; quadrupling means the whole thing is copied or walked each time.
;;
;; Run from the repository root: wat probes/aoc/conj-subs-scaling.wat

(:wat::core::typealias :probe::Ints (:wat::core::Vector :- [:wat::core::i64]))

(:wat::core::defn :probe::grow [n <- :wat::core::i64 acc <- :probe::Ints] -> :probe::Ints
  (:wat::core::if (:wat::core::= n 0)
    acc
    (:probe::grow (:wat::core::- n 1) (:wat::core::conj acc n))))

(:wat::core::defn :probe::scan [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:probe::scan s (:wat::core::+ i 1) n
      (:wat::core::+ acc (:wat::string::length (:wat::string::subs s i (:wat::core::+ i 1)))))))

(:wat::core::defn :probe::ms [] -> :wat::core::i64 (:wat::time::epoch-millis (:wat::time::now)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [text (:wat::io::read-file "aoc/input/day01-sonar.txt")
                    t0 (:probe::ms)
                    small (:probe::grow 5000 (:wat::core::Vector :- [:wat::core::i64]))
                    t1 (:probe::ms)
                    big (:probe::grow 10000 (:wat::core::Vector :- [:wat::core::i64]))
                    t2 (:probe::ms)
                    a (:probe::scan text 0 2000 0)
                    t3 (:probe::ms)
                    b (:probe::scan text 0 4000 0)
                    t4 (:probe::ms)]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "conj 5000 times: " (:wat::i64::to-string (:wat::core::- t1 t0)) " ms"))
      (:wat::kernel::println (:wat::string::concat "conj 10000 times: " (:wat::i64::to-string (:wat::core::- t2 t1)) " ms"))
      (:wat::kernel::println (:wat::string::concat "subs over 2000 characters: " (:wat::i64::to-string (:wat::core::- t3 t2)) " ms"))
      (:wat::kernel::println (:wat::string::concat "subs over 4000 characters: " (:wat::i64::to-string (:wat::core::- t4 t3)) " ms"))
      (:wat::test::assert-eq (:wat::core::length small) 5000)
      (:wat::test::assert-eq (:wat::core::length big) 10000)
      (:wat::test::assert-eq a 2000)
      (:wat::test::assert-eq b 4000))))
