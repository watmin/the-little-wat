;; Advent of Code's folding shape, in wat: a sheet of dots, folded until it reads.
;;
;; The input is a list of `x,y` dots, a blank line, then fold instructions. A fold along `y=v`
;; reflects every dot below the line upwards; `x=v` reflects every dot to the right leftwards.
;; Dots that land on each other merge.
;;
;; Part one: how many dots are left after the FIRST fold.
;; Part two: the picture after ALL the folds, one answer per row.
;;
;; What this one is here for:
;;
;;   * **An answer that is TEXT.** Every puzzle before this one answered with a number. Here the
;;     answer is six rows of a picture, and the check compares them to Clojure's character for
;;     character -- which is a harder thing to get accidentally right.
;;   * **Two-part input.** The file is two blocks separated by a blank line, so the parse splits
;;     on `"\n\n"` before it splits on `"\n"`. `:wat::string::split` takes a whole string as its
;;     separator, so that works; `lib/check.wat`'s line reader would have thrown the blank line
;;     away and lost the boundary.
;;   * **Dedup without a set.** F-057: no set shares structure, so merging dots is a
;;     `PersistentMap` to `true`, and the surviving dots come back out through its keys.
;;
;; The puzzle and its input are ours (aoc/input/day13-origami.txt); Advent of Code's own texts
;; and inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day13-origami.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day13-origami.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Dots (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::bool]))
(:wat::core::typealias :aoc::Ints (:wat::core::Vector :- [:wat::core::i64]))

(:wat::core::defrecord :aoc::Fold [axis <- :wat::core::String  v <- :wat::core::i64])

(:wat::core::defn :aoc::pack [x <- :wat::core::i64 y <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::+ (:wat::core::* x 100) y))

(:wat::core::defn :aoc::px [k <- :wat::core::i64] -> :wat::core::i64 (:wat::core::/ k 100))
(:wat::core::defn :aoc::py [k <- :wat::core::i64] -> :wat::core::i64 (:wat::core::rem k 100))

(:wat::core::defn :aoc::parse-dots [ls <- :aoc::Lines i <- :wat::core::i64 acc <- :aoc::Dots] -> :aoc::Dots
  (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) acc
    (:wat::core::let [parts (:wat::string::split (:wat::core::nth ls i) ",")]
      (:aoc::parse-dots ls (:wat::core::+ i 1)
        (:wat::map::assoc acc (:aoc::pack (:aoc::to-int (:wat::core::nth parts 0))
                                          (:aoc::to-int (:wat::core::nth parts 1))) true)))))

;; "fold along y=13" -> axis "y", v 13
(:wat::core::defn :aoc::parse-folds [ls <- :aoc::Lines i <- :wat::core::i64
                                     acc <- (:wat::core::Vector :- [:aoc::Fold])]
  -> (:wat::core::Vector :- [:aoc::Fold])
  (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) acc
    (:wat::core::let [words (:wat::string::split (:wat::core::nth ls i) " ")
                      spec (:wat::string::split (:wat::core::nth words 2) "=")]
      (:aoc::parse-folds ls (:wat::core::+ i 1)
        (:wat::core::conj acc (:aoc::Fold :axis (:wat::core::nth spec 0)
                                          :v (:aoc::to-int (:wat::core::nth spec 1))))))))

(:wat::core::defn :aoc::reflect [n <- :wat::core::i64 v <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> n v) (:wat::core::- (:wat::core::* 2 v) n) n))

(:wat::core::defn :aoc::fold-key [k <- :wat::core::i64 f <- :aoc::Fold] -> :wat::core::i64
  (:wat::core::if (:wat::core::= (:aoc::Fold/axis f) "y")
    (:aoc::pack (:aoc::px k) (:aoc::reflect (:aoc::py k) (:aoc::Fold/v f)))
    (:aoc::pack (:aoc::reflect (:aoc::px k) (:aoc::Fold/v f)) (:aoc::py k))))

(:wat::core::defn :aoc::fold-all [ks <- :aoc::Ints i <- :wat::core::i64 f <- :aoc::Fold
                                  acc <- :aoc::Dots] -> :aoc::Dots
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) acc
    (:aoc::fold-all ks (:wat::core::+ i 1) f
      (:wat::map::assoc acc (:aoc::fold-key (:wat::core::nth ks i) f) true))))

(:wat::core::defn :aoc::fold [d <- :aoc::Dots f <- :aoc::Fold] -> :aoc::Dots
  (:aoc::fold-all (:wat::map::keys d) 0 f
    (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::bool])))

(:wat::core::defn :aoc::fold-each [d <- :aoc::Dots fs <- (:wat::core::Vector :- [:aoc::Fold])
                                   i <- :wat::core::i64] -> :aoc::Dots
  (:wat::core::if (:wat::core::>= i (:wat::core::length fs)) d
    (:aoc::fold-each (:aoc::fold d (:wat::core::nth fs i)) fs (:wat::core::+ i 1))))

(:wat::core::defn :aoc::max-of [ks <- :aoc::Ints i <- :wat::core::i64 x? <- :wat::core::bool
                                acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) acc
    (:wat::core::let [v (:wat::core::if x? (:aoc::px (:wat::core::nth ks i)) (:aoc::py (:wat::core::nth ks i)))]
      (:aoc::max-of ks (:wat::core::+ i 1) x? (:wat::core::if (:wat::core::> v acc) v acc)))))

(:wat::core::defn :aoc::row [d <- :aoc::Dots y <- :wat::core::i64 x <- :wat::core::i64
                             w <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= x w) acc
    (:aoc::row d y (:wat::core::+ x 1) w
      (:wat::string::concat acc
        (:wat::core::if (:wat::map::contains-key? d (:aoc::pack x y)) "#" ".")))))

(:wat::core::defn :aoc::picture [d <- :aoc::Dots y <- :wat::core::i64 h <- :wat::core::i64
                                 w <- :wat::core::i64 acc <- :aoc::Lines] -> :aoc::Lines
  (:wat::core::if (:wat::core::>= y h) acc
    (:aoc::picture d (:wat::core::+ y 1) h w (:wat::core::conj acc (:aoc::row d y 0 w "")))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [blocks (:wat::string::split (:wat::io::read-file "aoc/input/day13-origami.txt") "\n\n")
     dots (:aoc::parse-dots (:aoc::non-empty (:wat::string::split (:wat::core::nth blocks 0) "\n")) 0
            (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::bool]))
     folds (:aoc::parse-folds (:aoc::non-empty (:wat::string::split (:wat::core::nth blocks 1) "\n")) 0
             (:wat::core::Vector :- [:aoc::Fold]))
     first-fold (:aoc::fold dots (:wat::core::nth folds 0))
     final (:aoc::fold-each dots folds 0)
     ks (:wat::map::keys final)
     w (:wat::core::+ (:aoc::max-of ks 0 true 0) 1)
     h (:wat::core::+ (:aoc::max-of ks 0 false 0) 1)
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day13-origami.expected"
                         "aoc day13 origami"
                         (:wat::core::concat
                           (:wat::core::Vector :- [:wat::core::String]
                             (int (:wat::core::length (:wat::map::keys first-fold))))
                           (:aoc::picture final 0 h w (:wat::core::Vector :- [:wat::core::String]))))))
