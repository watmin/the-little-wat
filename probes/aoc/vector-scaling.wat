;; probes/aoc/vector-scaling.wat: which of the puzzle-reading steps is linear, and which isn't?
;; aoc/day01-sonar.wat takes about 1.1 s for 2000 readings and aoc/day02-smoke.wat about 1.8 s
;; for a 100x100 grid, against about 0.3 s of startup. The candidates are indexing a Vector with
;; nth, growing one with conj (which clones, F-023), and taking one-character substrings.
;;
;; Each step runs at two sizes, n and 2n, and prints the work it did. Doubling the time means
;; linear; quadrupling it means quadratic.
;;
;; Run from the repository root: wat probes/aoc/vector-scaling.wat
;; (time each half by running it with SIZE 2000 and 4000 — the two halves are printed apart)

(:wat::core::typealias :probe::Ints (:wat::core::Vector :- [:wat::core::i64]))

;; grow a Vector by conj, n times
(:wat::core::defn :probe::grow [n <- :wat::core::i64 acc <- :probe::Ints] -> :probe::Ints
  (:wat::core::if (:wat::core::= n 0)
    acc
    (:probe::grow (:wat::core::- n 1) (:wat::core::conj acc n))))

;; read every element by index
(:wat::core::defn :probe::sum-by-index [xs <- :probe::Ints i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs))
    acc
    (:probe::sum-by-index xs (:wat::core::+ i 1) (:wat::core::+ acc (:wat::core::nth xs i)))))

;; read every element by walking the rest
(:wat::core::defn :probe::sum-by-rest [xs <- :probe::Ints acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::empty? xs)
    acc
    (:probe::sum-by-rest (:wat::core::rest xs) (:wat::core::+ acc (:wat::core::first xs)))))

;; one-character substrings, left to right
(:wat::core::defn :probe::scan [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:probe::scan s (:wat::core::+ i 1) n (:wat::core::+ acc (:wat::string::length (:wat::string::subs s i (:wat::core::+ i 1)))))))

(:wat::core::defn :probe::report [label <- :wat::core::String n <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label " " (:wat::i64::to-string n))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [text (:wat::io::read-file "aoc/input/day01-sonar.txt")
                    small (:probe::grow 2000 (:wat::core::Vector :- [:wat::core::i64]))
                    _a (:probe::report "grew by conj to" (:wat::core::length small))
                    big (:probe::grow 4000 (:wat::core::Vector :- [:wat::core::i64]))
                    _b (:probe::report "grew by conj to" (:wat::core::length big))
                    _c (:probe::report "summed 2000 by index:" (:probe::sum-by-index small 0 0))
                    _d (:probe::report "summed 4000 by index:" (:probe::sum-by-index big 0 0))
                    _e (:probe::report "summed 2000 by rest:" (:probe::sum-by-rest small 0))
                    _f (:probe::report "summed 4000 by rest:" (:probe::sum-by-rest big 0))
                    _g (:probe::report "scanned 2000 characters:" (:probe::scan text 0 2000 0))]
    (:probe::report "scanned 4000 characters:" (:probe::scan text 0 4000 0))))
