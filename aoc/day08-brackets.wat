;; Advent of Code's bracket shape, in wat: lines of brackets, checked with a stack.
;;
;; Part one: the syntax-error score. A line is CORRUPTED when a closing bracket does not match
;; the most recent unclosed opening one; each wrong closer scores 3, 57, 1197 or 25137.
;; Part two: the completion score. A line that is not corrupted is INCOMPLETE; close it, scoring
;; each closer as score*5 + 1..4, and take the MEDIAN.
;;
;; **This is the puzzle F-116 is about.** A stack machine's pop has no constant-time spelling in
;; wat -- there is no `pop`, no `subvec`, `take` and `drop` answer a Stream with no way back
;; (F-088), and neither vector type has a positional update (F-104) -- so `:aoc::pop` rebuilds.
;; What makes this puzzle worth having anyway is the SIZE: a bracket stack here is at most nine
;; deep, and C-113 measured that at those depths the rebuild costs nothing worth naming. F-116 is
;; a finding about VM stacks that reach thousands, not about stacks that reach nine, and this is
;; the workload that shows the difference.
;;
;; Characters come one `subs` at a time (F-062), because a String has no elements.
;;
;; The puzzle and its input are ours (aoc/input/day08-brackets.txt); Advent of Code's own texts
;; and inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day08-brackets.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day08-brackets.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Stack (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defenum :aoc::Scan :wat::enum::Pure
  :Corrupt [ch <- :wat::core::String]
  :Incomplete [stack <- :aoc::Stack])

;; the closer an opener wants, or "" when the character is not an opener
(:wat::core::defn :aoc::closer-of [c <- :wat::core::String] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= c "(") ")")
    ((:wat::core::= c "[") "]")
    ((:wat::core::= c "{") "}")
    ((:wat::core::= c "<") ">")
    (:else "")))

(:wat::core::defn :aoc::err-score [c <- :wat::core::String] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::= c ")") 3)
    ((:wat::core::= c "]") 57)
    ((:wat::core::= c "}") 1197)
    (:else 25137)))

(:wat::core::defn :aoc::fin-score [c <- :wat::core::String] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::= c ")") 1)
    ((:wat::core::= c "]") 2)
    ((:wat::core::= c "}") 3)
    (:else 4)))

;; F-116: the pop. Everything below the top, rebuilt.
(:wat::core::defn :aoc::take-k [s <- :aoc::Stack k <- :wat::core::i64 i <- :wat::core::i64
                                acc <- :aoc::Stack] -> :aoc::Stack
  (:wat::core::if (:wat::core::>= i k) acc
    (:aoc::take-k s k (:wat::core::+ i 1) (:wat::core::conj acc (:wat::core::nth s i)))))

(:wat::core::defn :aoc::pop [s <- :aoc::Stack] -> :aoc::Stack
  (:aoc::take-k s (:wat::core::- (:wat::core::length s) 1) 0 (:wat::core::Vector :- [:wat::core::String])))

(:wat::core::defn :aoc::top [s <- :aoc::Stack] -> :wat::core::String
  (:wat::core::nth s (:wat::core::- (:wat::core::length s) 1)))

(:wat::core::defn :aoc::scan [line <- :wat::core::String n <- :wat::core::i64 i <- :wat::core::i64
                              st <- :aoc::Stack] -> :aoc::Scan
  (:wat::core::if (:wat::core::>= i n) (:aoc::Scan.Incomplete {:stack st})
    (:wat::core::let [c (:wat::string::subs line i (:wat::core::+ i 1))
                      want (:aoc::closer-of c)]
      (:wat::core::cond
        ;; an opener: push the closer it will want
        ((:wat::core::not (:wat::core::= want "")) (:aoc::scan line n (:wat::core::+ i 1) (:wat::core::conj st want)))
        ;; a closer that matches the top: pop
        ((:wat::core::and (:wat::core::> (:wat::core::length st) 0) (:wat::core::= c (:aoc::top st)))
          (:aoc::scan line n (:wat::core::+ i 1) (:aoc::pop st)))
        ;; anything else is the first corruption, and the line stops there
        (:else (:aoc::Scan.Corrupt {:ch c}))))))

(:wat::core::defn :aoc::scan-line [line <- :wat::core::String] -> :aoc::Scan
  (:aoc::scan line (:wat::string::length line) 0 (:wat::core::Vector :- [:wat::core::String])))

;; the completion score: the stack from the TOP down, each closer worth 1 to 4
(:wat::core::defn :aoc::complete [st <- :aoc::Stack i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< i 0) acc
    (:aoc::complete st (:wat::core::- i 1)
      (:wat::core::+ (:wat::core::* acc 5) (:aoc::fin-score (:wat::core::nth st i))))))

(:wat::core::defn :aoc::errors [ls <- :aoc::Lines i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) acc
    (:aoc::errors ls (:wat::core::+ i 1)
      (:wat::core::match (:aoc::scan-line (:wat::core::nth ls i))
        [:aoc::Scan.Corrupt {:ch c} (:wat::core::+ acc (:aoc::err-score c))]
        [:aoc::Scan.Incomplete {:stack st} acc]))))

(:wat::core::defn :aoc::completions [ls <- :aoc::Lines i <- :wat::core::i64
                                     acc <- (:wat::core::Vector :- [:wat::core::i64])]
  -> (:wat::core::Vector :- [:wat::core::i64])
  (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) acc
    (:aoc::completions ls (:wat::core::+ i 1)
      (:wat::core::match (:aoc::scan-line (:wat::core::nth ls i))
        [:aoc::Scan.Corrupt {:ch c} acc]
        [:aoc::Scan.Incomplete {:stack st}
          (:wat::core::conj acc (:aoc::complete st (:wat::core::- (:wat::core::length st) 1) 0))]))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [lines (:aoc::lines "aoc/input/day08-brackets.txt")
     scores (:wat::core::sort (:aoc::completions lines 0 (:wat::core::Vector :- [:wat::core::i64])))
     mid (:wat::core::/ (:wat::core::length scores) 2)
     int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:aoc::check-answers "oracle/aoc/day08-brackets.expected"
                         "aoc day08 brackets"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::errors lines 0 0))
                           (int (:wat::core::nth scores mid))))))
