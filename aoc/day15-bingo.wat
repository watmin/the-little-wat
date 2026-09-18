;; Advent of Code's bingo shape, in wat: boards marked as numbers are drawn.
;;
;; The input is a draw order, a blank line, then 5x5 boards separated by blank lines. A board
;; wins when a whole row or a whole column is marked; its score is the sum of its unmarked
;; numbers times the number just drawn.
;;
;; Part one: the score of the FIRST board to win.
;; Part two: the score of the LAST.
;;
;; Two things this one is here for:
;;
;;   * **Structured input.** Not a list of numbers and not a grid: a header line, then twenty
;;     records separated by blank lines, each five rows of five columns aligned with spaces. The
;;     parse splits on `"\n\n"`, then on whitespace runs -- and `:wat::string::split` has no
;;     regular-expression form, so the run of spaces is handled by splitting on `" "` and
;;     dropping the empties. F-061 (the whole regex surface is `matches?`) is why.
;;   * **Marking, which is a positional update.** F-104: no vector has one, so marking a square
;;     rebuilds the board's 25-element mark vector. At 25 elements that is free -- the same point
;;     day08's nine-deep stack and day10's nine counters make, and the opposite of what F-116
;;     measured at four thousand.
;;
;; The puzzle and its input are ours (aoc/input/day15-bingo.txt); Advent of Code's own texts and
;; inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day15-bingo.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day15-bingo.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Ints (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :aoc::Marks (:wat::core::Vector :- [:wat::core::bool]))

(:wat::core::defrecord :aoc::Board [nums <- :aoc::Ints  marks <- :aoc::Marks  won <- :wat::core::bool])
(:wat::core::typealias :aoc::Boards (:wat::core::Vector :- [:aoc::Board]))

;; F-061: no regex, so a run of spaces is a split on one space with the empties dropped
(:wat::core::defn :aoc::fields [s <- :wat::core::String] -> :aoc::Lines
  (:aoc::non-empty (:wat::string::split (:wat::string::trim s) " ")))

(:wat::core::defn :aoc::parse-board [block <- :wat::core::String] -> :aoc::Board
  (:wat::core::let [ns (:wat::core::mapv :aoc::to-int
                         (:aoc::fields (:wat::string::join " "
                           (:aoc::non-empty (:wat::string::split block "\n")))))]
    (:aoc::Board :nums ns :marks (:aoc::falses 0 (:wat::core::Vector :- [:wat::core::bool])) :won false)))

(:wat::core::defn :aoc::falses [i <- :wat::core::i64 acc <- :aoc::Marks] -> :aoc::Marks
  (:wat::core::if (:wat::core::>= i 25) acc (:aoc::falses (:wat::core::+ i 1) (:wat::core::conj acc false))))

;; F-104: marking is a rebuild. Twenty-five elements, so it costs nothing.
(:wat::core::defn :aoc::mark-at [m <- :aoc::Marks k <- :wat::core::i64 j <- :wat::core::i64
                                 acc <- :aoc::Marks] -> :aoc::Marks
  (:wat::core::if (:wat::core::>= j (:wat::core::length m)) acc
    (:aoc::mark-at m k (:wat::core::+ j 1)
      (:wat::core::conj acc (:wat::core::or (:wat::core::= j k) (:wat::core::nth m j))))))

(:wat::core::defn :aoc::mark [b <- :aoc::Board d <- :wat::core::i64 j <- :wat::core::i64] -> :aoc::Board
  (:wat::core::if (:wat::core::>= j 25) b
    (:aoc::mark (:wat::core::if (:wat::core::= (:wat::core::nth (:aoc::Board/nums b) j) d)
                  (:wat::core::assoc b :marks
                    (:aoc::mark-at (:aoc::Board/marks b) j 0 (:wat::core::Vector :- [:wat::core::bool])))
                  b)
      d (:wat::core::+ j 1))))

(:wat::core::defn :aoc::row-full? [m <- :aoc::Marks r <- :wat::core::i64 c <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::>= c 5) true)
    ((:wat::core::not (:wat::core::nth m (:wat::core::+ (:wat::core::* r 5) c))) false)
    (:else (:aoc::row-full? m r (:wat::core::+ c 1)))))

(:wat::core::defn :aoc::col-full? [m <- :aoc::Marks c <- :wat::core::i64 r <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::>= r 5) true)
    ((:wat::core::not (:wat::core::nth m (:wat::core::+ (:wat::core::* r 5) c))) false)
    (:else (:aoc::col-full? m c (:wat::core::+ r 1)))))

(:wat::core::defn :aoc::any-line? [m <- :aoc::Marks i <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::>= i 5) false)
    ((:aoc::row-full? m i 0) true)
    ((:aoc::col-full? m i 0) true)
    (:else (:aoc::any-line? m (:wat::core::+ i 1)))))

(:wat::core::defn :aoc::unmarked [b <- :aoc::Board j <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= j 25) acc
    (:aoc::unmarked b (:wat::core::+ j 1)
      (:wat::core::if (:wat::core::nth (:aoc::Board/marks b) j) acc
        (:wat::core::+ acc (:wat::core::nth (:aoc::Board/nums b) j))))))

;; one draw, applied to every board; every board that wins on it records a score, in board order
(:wat::core::defrecord :aoc::Play [boards <- :aoc::Boards  scores <- :aoc::Ints])

(:wat::core::defn :aoc::draw-one [p <- :aoc::Play d <- :wat::core::i64 i <- :wat::core::i64] -> :aoc::Play
  (:wat::core::if (:wat::core::>= i (:wat::core::length (:aoc::Play/boards p))) p
    (:wat::core::let [b (:wat::core::nth (:aoc::Play/boards p) i)]
      (:wat::core::if (:aoc::Board/won b) (:aoc::draw-one p d (:wat::core::+ i 1))
        (:wat::core::let
          [b2 (:aoc::mark b d 0)
           w (:aoc::any-line? (:aoc::Board/marks b2) 0)
           b3 (:wat::core::if w (:wat::core::assoc b2 :won true) b2)]
          (:aoc::draw-one
            (:aoc::Play :boards (:aoc::boards-set (:aoc::Play/boards p) i b3 0 (:wat::core::Vector :- [:aoc::Board]))
                        :scores (:wat::core::if w
                                  (:wat::core::conj (:aoc::Play/scores p)
                                    (:wat::core::* d (:aoc::unmarked b3 0 0)))
                                  (:aoc::Play/scores p)))
            d (:wat::core::+ i 1)))))))

(:wat::core::defn :aoc::boards-set [bs <- :aoc::Boards i <- :wat::core::i64 b <- :aoc::Board
                                    j <- :wat::core::i64 acc <- :aoc::Boards] -> :aoc::Boards
  (:wat::core::if (:wat::core::>= j (:wat::core::length bs)) acc
    (:aoc::boards-set bs i b (:wat::core::+ j 1)
      (:wat::core::conj acc (:wat::core::if (:wat::core::= j i) b (:wat::core::nth bs j))))))

(:wat::core::defn :aoc::play [p <- :aoc::Play ds <- :aoc::Ints i <- :wat::core::i64] -> :aoc::Play
  (:wat::core::if (:wat::core::>= i (:wat::core::length ds)) p
    (:aoc::play (:aoc::draw-one p (:wat::core::nth ds i) 0) ds (:wat::core::+ i 1))))

(:wat::core::defn :aoc::parse-boards [bs <- :aoc::Lines i <- :wat::core::i64 acc <- :aoc::Boards] -> :aoc::Boards
  (:wat::core::if (:wat::core::>= i (:wat::core::length bs)) acc
    (:aoc::parse-boards bs (:wat::core::+ i 1)
      (:wat::core::conj acc (:aoc::parse-board (:wat::core::nth bs i))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [blocks (:wat::string::split (:wat::string::trim (:wat::io::read-file "aoc/input/day15-bingo.txt")) "\n\n")
     draws (:wat::core::mapv :aoc::to-int
             (:wat::string::split (:wat::string::trim (:wat::core::nth blocks 0)) ","))
     boards (:aoc::parse-boards (:wat::core::rest blocks) 0 (:wat::core::Vector :- [:aoc::Board]))
     done (:aoc::play (:aoc::Play :boards boards :scores (:wat::core::Vector :- [:wat::core::i64])) draws 0)
     scores (:aoc::Play/scores done)
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day15-bingo.expected"
                         "aoc day15 bingo"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:wat::core::nth scores 0))
                           (int (:wat::core::nth scores (:wat::core::- (:wat::core::length scores) 1)))))))
