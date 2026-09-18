;; Advent of Code's twenty-fifth day, in wat: two herds shuffling until they jam.
;;
;; `>` moves one square east, `v` one square south, and both wrap around the edges. Every east
;; mover that can move does so AT THE SAME INSTANT; then every south mover that can. A square is
;; free only if it is free at the moment that herd moves.
;;
;; The answer: the number of the first step on which nothing moves at all. Advent of Code's
;; twenty-fifth day has one part, so this puzzle has one answer — and it is the last of the
;; twenty-five, which finishes NEXT.md's fourth acceptance test.
;;
;; **The simultaneity is the whole puzzle, and it is the one thing immutability makes easy.** A
;; mutable grid has to be careful: move a cucumber and the next one sees the new state, which is
;; not what "at the same instant" means, so an in-place solution needs a second buffer and the
;; discipline to use it. Here there is no choice to get wrong. Each step READS the old grid and
;; BUILDS a new one, and a square decides its own next contents by looking at itself, the square
;; behind it and the square ahead — three reads of a grid that cannot change underneath.
;;
;; That is worth stating plainly at the end of a suite whose findings are mostly costs. F-104's
;; missing positional update is what forces the rebuild, and here the rebuild IS the algorithm.
;;
;; The puzzle and its input are ours (aoc/input/day25-cucumbers.txt); Advent of Code's own texts
;; and inputs are not redistributable. The answer must be the reference implementation's
;; (oracle/aoc/day25-cucumbers.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day25-cucumbers.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defn :aoc::wrap [n <- :wat::core::i64 m <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::rem (:wat::core::+ (:wat::core::rem n m) m) m))

(:wat::core::defn :aoc::at [g <- :aoc::Lines h <- :wat::core::i64 w <- :wat::core::i64
                            r <- :wat::core::i64 c <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [rr (:aoc::wrap r h) cc (:aoc::wrap c w)]
    (:wat::string::subs (:wat::core::nth g rr) cc (:wat::core::+ cc 1))))

;; a square's next contents, decided by looking backwards and forwards -- never by moving anything
(:wat::core::defn :aoc::next-cell [g <- :aoc::Lines h <- :wat::core::i64 w <- :wat::core::i64
                                   who <- :wat::core::String dr <- :wat::core::i64 dc <- :wat::core::i64
                                   r <- :wat::core::i64 c <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [here (:aoc::at g h w r c)
                    from (:aoc::at g h w (:wat::core::- r dr) (:wat::core::- c dc))
                    to (:aoc::at g h w (:wat::core::+ r dr) (:wat::core::+ c dc))]
    (:wat::core::cond
      ((:wat::core::and (:wat::core::= here who) (:wat::core::= to ".")) ".")
      ((:wat::core::and (:wat::core::= here ".") (:wat::core::= from who)) who)
      (:else here))))

(:wat::core::defn :aoc::next-row [g <- :aoc::Lines h <- :wat::core::i64 w <- :wat::core::i64
                                  who <- :wat::core::String dr <- :wat::core::i64 dc <- :wat::core::i64
                                  r <- :wat::core::i64 c <- :wat::core::i64
                                  acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= c w) acc
    (:aoc::next-row g h w who dr dc r (:wat::core::+ c 1)
      (:wat::string::concat acc (:aoc::next-cell g h w who dr dc r c)))))

(:wat::core::defn :aoc::move [g <- :aoc::Lines h <- :wat::core::i64 w <- :wat::core::i64
                              who <- :wat::core::String dr <- :wat::core::i64 dc <- :wat::core::i64
                              r <- :wat::core::i64 acc <- :aoc::Lines] -> :aoc::Lines
  (:wat::core::if (:wat::core::>= r h) acc
    (:aoc::move g h w who dr dc (:wat::core::+ r 1)
      (:wat::core::conj acc (:aoc::next-row g h w who dr dc r 0 "")))))

(:wat::core::defn :aoc::same? [a <- :aoc::Lines b <- :aoc::Lines i <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length a)) true)
    ((:wat::core::not (:wat::core::= (:wat::core::nth a i) (:wat::core::nth b i))) false)
    (:else (:aoc::same? a b (:wat::core::+ i 1)))))

(:wat::core::defn :aoc::step [g <- :aoc::Lines h <- :wat::core::i64 w <- :wat::core::i64] -> :aoc::Lines
  (:aoc::move (:aoc::move g h w ">" 0 1 0 (:wat::core::Vector :- [:wat::core::String]))
    h w "v" 1 0 0 (:wat::core::Vector :- [:wat::core::String])))

(:wat::core::defn :aoc::settle [g <- :aoc::Lines h <- :wat::core::i64 w <- :wat::core::i64
                                n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [g2 (:aoc::step g h w)]
    (:wat::core::if (:aoc::same? g g2 0) n (:aoc::settle g2 h w (:wat::core::+ n 1)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [g (:aoc::lines "aoc/input/day25-cucumbers.txt")
     h (:wat::core::length g)
     w (:wat::string::length (:wat::core::nth g 0))
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day25-cucumbers.expected"
                         "aoc day25 cucumbers"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::settle g h w 1))))))
