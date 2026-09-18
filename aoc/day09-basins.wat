;; Advent of Code's flood-fill shape, in wat: a grid of heights, and the basins the 9s divide it
;; into.
;;
;; Part one: how many basins there are. A basin is a maximal region of cells below 9, joined up,
;; down, left and right.
;; Part two: the product of the three largest basins' sizes.
;;
;; Three things this puzzle is here for, none of them the algorithm:
;;
;;   * **Recursion.** The fill is written the way the problem reads -- four recursive calls per
;;     cell -- and the largest basin here is 266 cells, so the deepest path is well inside the
;;     limit F-099 measured (fine to 100000 frames, SIGSEGV at 120000, with an empty stderr).
;;     A basin the size of the whole grid would not be.
;;   * **The visited set, which does not exist.** F-057: `PersistentVector` and `PersistentMap`
;;     share structure and no set does, so `seen` is a `PersistentMap` to `true`. The reference
;;     implementation says `#{}`.
;;   * **Threading state through a recursion that branches.** `seen` has to come back out of each
;;     of the four calls to go into the next, so the fill answers a record of (seen, count) --
;;     which is what a mutable set would have made unnecessary.
;;
;; The puzzle and its input are ours (aoc/input/day09-basins.txt); Advent of Code's own texts and
;; inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day09-basins.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day09-basins.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Seen (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::bool]))

;; the fill answers both what it saw and how much of it there was
(:wat::core::defrecord :aoc::Fl [seen <- :aoc::Seen  n <- :wat::core::i64])

(:wat::core::defn :aoc::digit-at [g <- :aoc::Lines r <- :wat::core::i64 c <- :wat::core::i64] -> :wat::core::i64
  (:aoc::to-int (:wat::string::subs (:wat::core::nth g r) c (:wat::core::+ c 1))))

(:wat::core::defn :aoc::key-of [w <- :wat::core::i64 r <- :wat::core::i64 c <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::+ (:wat::core::* r w) c))

(:wat::core::defn :aoc::flood [g <- :aoc::Lines h <- :wat::core::i64 w <- :wat::core::i64
                               seen <- :aoc::Seen r <- :wat::core::i64 c <- :wat::core::i64] -> :aoc::Fl
  (:wat::core::if
    (:wat::core::or (:wat::core::< r 0)
      (:wat::core::or (:wat::core::< c 0)
        (:wat::core::or (:wat::core::>= r h)
          (:wat::core::or (:wat::core::>= c w)
            (:wat::core::or (:wat::map::contains-key? seen (:aoc::key-of w r c))
                            (:wat::core::= (:aoc::digit-at g r c) 9))))))
    (:aoc::Fl :seen seen :n 0)
    (:wat::core::let
      [s1 (:wat::map::assoc seen (:aoc::key-of w r c) true)
       a (:aoc::flood g h w s1 (:wat::core::+ r 1) c)
       b (:aoc::flood g h w (:aoc::Fl/seen a) (:wat::core::- r 1) c)
       d (:aoc::flood g h w (:aoc::Fl/seen b) r (:wat::core::+ c 1))
       e (:aoc::flood g h w (:aoc::Fl/seen d) r (:wat::core::- c 1))]
      (:aoc::Fl :seen (:aoc::Fl/seen e)
                :n (:wat::core::+ 1
                     (:wat::core::+ (:aoc::Fl/n a)
                       (:wat::core::+ (:aoc::Fl/n b)
                         (:wat::core::+ (:aoc::Fl/n d) (:aoc::Fl/n e)))))))))

;; the sizes of every basin, found by scanning the grid and filling from each unseen low cell
(:wat::core::defrecord :aoc::Scan
  [seen <- :aoc::Seen  sizes <- (:wat::core::Vector :- [:wat::core::i64])])

(:wat::core::defn :aoc::scan-cells [g <- :aoc::Lines h <- :wat::core::i64 w <- :wat::core::i64
                                    i <- :wat::core::i64 st <- :aoc::Scan] -> :aoc::Scan
  (:wat::core::if (:wat::core::>= i (:wat::core::* h w)) st
    (:wat::core::let [r (:wat::core::/ i w)
                      c (:wat::core::rem i w)]
      (:wat::core::if (:wat::core::or (:wat::core::= (:aoc::digit-at g r c) 9)
                                      (:wat::map::contains-key? (:aoc::Scan/seen st) (:aoc::key-of w r c)))
        (:aoc::scan-cells g h w (:wat::core::+ i 1) st)
        (:wat::core::let [f (:aoc::flood g h w (:aoc::Scan/seen st) r c)]
          (:aoc::scan-cells g h w (:wat::core::+ i 1)
            (:aoc::Scan :seen (:aoc::Fl/seen f)
                        :sizes (:wat::core::conj (:aoc::Scan/sizes st) (:aoc::Fl/n f)))))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [g (:aoc::lines "aoc/input/day09-basins.txt")
     h (:wat::core::length g)
     w (:wat::string::length (:wat::core::nth g 0))
     found (:aoc::scan-cells g h w 0
             (:aoc::Scan :seen (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::bool])
                         :sizes (:wat::core::Vector :- [:wat::core::i64])))
     sizes (:wat::core::sort (:aoc::Scan/sizes found))
     n (:wat::core::length sizes)
     ;; sort is ascending, so the three largest are the last three
     top3 (:wat::core::* (:wat::core::nth sizes (:wat::core::- n 1))
            (:wat::core::* (:wat::core::nth sizes (:wat::core::- n 2))
                           (:wat::core::nth sizes (:wat::core::- n 3))))
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day09-basins.expected"
                         "aoc day09 basins"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int n)
                           (int top3)))))
