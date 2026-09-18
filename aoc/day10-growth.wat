;; Advent of Code's exponential-growth shape, in wat: a population on a timer.
;;
;; Each number is a timer. Every day every timer drops by one; a timer at 0 becomes 6 and adds a
;; new timer at 8. Simulating the list is impossible -- after 500 days there are 2.6 x 10^21 of
;; them -- so the answer is NINE COUNTERS, one per timer value, rotated once a day.
;;
;; **Part two does not fit in 64 bits, and that is why it is here.** Two things follow:
;;
;;   * wat's i64 **traps** rather than wrapping. The same program in i64 dies with
;;     *"i64 overflow: … :wat::i64::+ … does not fit in 64 bits"*, naming the operation and both
;;     operands -- better than C's silence and Java's wrap. The one complaint is the F-006/F-008
;;     family: the error locates at `wat/core.wat:66`, inside wat's own stdlib, not at the line
;;     of the program that overflowed.
;;   * so part two is a bigint, and **F-060 has to be worked around a second time, in a second
;;     suite**. A bigint has no `to-string`; its digits come from `:wat::core::str`, which appends
;;     an `N`, so every answer is stripped. `euler/p57-p71-rationals.wat` needed the identical
;;     helper, which is the point of having it twice.
;;
;; Part one: the population after 80 days (an i64, to show where the boundary is).
;; Part two: the population after 500 days (a bigint, because there is no choice).
;;
;; The puzzle and its input are ours (aoc/input/day10-growth.txt); Advent of Code's own texts and
;; inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day10-growth.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day10-growth.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Buckets (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :aoc::Bigs (:wat::core::Vector :- [:wat::core::bigint]))

;; F-060 again: a bigint's digits come out through `str`, with an `N` to remove
(:wat::core::defn :aoc::bigstr [b <- :wat::core::bigint] -> :wat::core::String
  (:wat::core::let [s (:wat::core::str b)]
    (:wat::string::subs s 0 (:wat::core::- (:wat::string::length s) 1))))

(:wat::core::defn :aoc::count-of [xs <- :aoc::Buckets v <- :wat::core::i64
                                  i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs)) acc
    (:aoc::count-of xs v (:wat::core::+ i 1)
      (:wat::core::if (:wat::core::= (:wat::core::nth xs i) v) (:wat::core::+ acc 1) acc))))

(:wat::core::defn :aoc::start-buckets [xs <- :aoc::Buckets i <- :wat::core::i64 acc <- :aoc::Buckets] -> :aoc::Buckets
  (:wat::core::if (:wat::core::>= i 9) acc
    (:aoc::start-buckets xs (:wat::core::+ i 1) (:wat::core::conj acc (:aoc::count-of xs i 0 0)))))

;; one day: shift left by one, the timers at 0 reappear at 6 and spawn at 8. Nine elements, so
;; rebuilding the whole vector costs nothing -- F-104's positional update is not missed at this
;; size, which C-113 is the general statement of.
(:wat::core::defn :aoc::step [b <- :aoc::Buckets] -> :aoc::Buckets
  (:wat::core::let [z (:wat::core::nth b 0)]
    (:wat::core::Vector :- [:wat::core::i64]
      (:wat::core::nth b 1) (:wat::core::nth b 2) (:wat::core::nth b 3)
      (:wat::core::nth b 4) (:wat::core::nth b 5) (:wat::core::nth b 6)
      (:wat::core::+ (:wat::core::nth b 7) z) (:wat::core::nth b 8) z)))

(:wat::core::defn :aoc::run-days [b <- :aoc::Buckets n <- :wat::core::i64] -> :aoc::Buckets
  (:wat::core::if (:wat::core::= n 0) b (:aoc::run-days (:aoc::step b) (:wat::core::- n 1))))

(:wat::core::defn :aoc::total [b <- :aoc::Buckets i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length b)) acc
    (:aoc::total b (:wat::core::+ i 1) (:wat::core::+ acc (:wat::core::nth b i)))))

;; ---- the same thing in bigint, because 500 days does not fit
(:wat::core::defn :aoc::to-bigs [b <- :aoc::Buckets i <- :wat::core::i64 acc <- :aoc::Bigs] -> :aoc::Bigs
  (:wat::core::if (:wat::core::>= i (:wat::core::length b)) acc
    (:aoc::to-bigs b (:wat::core::+ i 1)
      (:wat::core::conj acc (:wat::i64::to-bigint (:wat::core::nth b i))))))

(:wat::core::defn :aoc::bstep [b <- :aoc::Bigs] -> :aoc::Bigs
  (:wat::core::let [z (:wat::core::nth b 0)]
    (:wat::core::Vector :- [:wat::core::bigint]
      (:wat::core::nth b 1) (:wat::core::nth b 2) (:wat::core::nth b 3)
      (:wat::core::nth b 4) (:wat::core::nth b 5) (:wat::core::nth b 6)
      (:wat::bigint::+ (:wat::core::nth b 7) z) (:wat::core::nth b 8) z)))

(:wat::core::defn :aoc::brun [b <- :aoc::Bigs n <- :wat::core::i64] -> :aoc::Bigs
  (:wat::core::if (:wat::core::= n 0) b (:aoc::brun (:aoc::bstep b) (:wat::core::- n 1))))

(:wat::core::defn :aoc::btotal [b <- :aoc::Bigs i <- :wat::core::i64 acc <- :wat::core::bigint] -> :wat::core::bigint
  (:wat::core::if (:wat::core::>= i (:wat::core::length b)) acc
    (:aoc::btotal b (:wat::core::+ i 1) (:wat::bigint::+ acc (:wat::core::nth b i)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [text (:wat::string::trim (:wat::io::read-file "aoc/input/day10-growth.txt"))
     timers (:wat::core::mapv :aoc::to-int (:wat::string::split text ","))
     start (:aoc::start-buckets timers 0 (:wat::core::Vector :- [:wat::core::i64]))
     bigs (:aoc::to-bigs start 0 (:wat::core::Vector :- [:wat::core::bigint]))
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day10-growth.expected"
                         "aoc day10 growth"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::total (:aoc::run-days start 80) 0 0))
                           (:aoc::bigstr (:aoc::btotal (:aoc::brun bigs 500) 0
                                           (:wat::i64::to-bigint 0)))))))
