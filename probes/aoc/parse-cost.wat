;; probes/aoc/parse-cost.wat: where does the time go reading a puzzle's input? aoc/day01-sonar.wat
;; takes about 1.1 s for 2000 readings, against about 0.3 s of startup, and the work itself is
;; two passes over 2000 numbers.
;;
;; This does each step on its own, 2000 readings at a time, printing after each so the steps can
;; be timed apart: read the file, split it into lines, parse each to an i64, index every element
;; with nth, and take every three-element window.
;;
;; Run from the repository root: time wat probes/aoc/parse-cost.wat

(:wat::core::typealias :probe::Ints (:wat::core::Vector :- [:wat::core::i64]))

(:wat::core::defn :probe::to-int [s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::string::to-i64 s)
    [:wat::core::Option.Some {:value n} n]
    [:wat::core::Option.None {} 0]))

;; every element, by index: the shape a loop over a Vector takes
(:wat::core::defn :probe::sum-by-index [xs <- :probe::Ints i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs))
    acc
    (:probe::sum-by-index xs (:wat::core::+ i 1) (:wat::core::+ acc (:wat::core::nth xs i)))))

(:wat::core::defn :probe::sum [xs <- :probe::Ints] -> :wat::core::i64
  (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ a b)) 0 xs))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [text (:wat::io::read-file "aoc/input/day01-sonar.txt")
                    _a (:wat::kernel::println (:wat::string::concat "read: " (:wat::i64::to-string (:wat::string::length text)) " characters"))
                    lines (:wat::string::split text "\n")
                    _b (:wat::kernel::println (:wat::string::concat "split: " (:wat::i64::to-string (:wat::core::length lines)) " lines"))
                    kept (:wat::core::filterv (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool (:wat::core::not (:wat::core::= s ""))) lines)
                    depths (:wat::core::mapv :probe::to-int kept)
                    _c (:wat::kernel::println (:wat::string::concat "parsed: " (:wat::i64::to-string (:wat::core::length depths)) " numbers"))
                    by-index (:probe::sum-by-index depths 0 0)
                    _d (:wat::kernel::println (:wat::string::concat "summed by index: " (:wat::i64::to-string by-index)))
                    by-fold (:probe::sum depths)
                    _e (:wat::kernel::println (:wat::string::concat "summed by foldl: " (:wat::i64::to-string by-fold)))
                    windows (:wat::seq::window depths 3)
                    _f (:wat::kernel::println (:wat::string::concat "windowed: " (:wat::i64::to-string (:wat::core::length windows)) " windows of three"))
                    sums (:wat::core::mapv :probe::sum windows)]
    (:wat::kernel::println (:wat::string::concat "window sums: " (:wat::i64::to-string (:wat::core::length sums))))))
