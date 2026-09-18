;; Advent of Code's nested-pair shape, in wat: numbers that reduce as they are added.
;;
;; A number is a pair, and each side is a number or a digit. Adding two makes a new pair, which
;; is then REDUCED: while any pair sits deeper than four, the leftmost such pair EXPLODES (its
;; left value adds to the nearest value on its left, its right to the nearest on its right, and
;; the pair becomes 0); otherwise, while any value is 10 or more, the leftmost SPLITS into two
;; halves, rounded down then up. The magnitude of a pair is 3 × left + 2 × right.
;;
;; Part one: the magnitude of the sum of every number, in order.
;; Part two: the largest magnitude of any two different numbers added.
;;
;; **The representation is the whole decision, and it is not the obvious one.** A snailfish
;; number is a recursive pair, which is a `defenum` and which wat handles well -- `eopl/` and
;; `lox/` are twenty-odd programs' worth of evidence. But "the nearest value on the LEFT" is not
;; a tree operation: it is a traversal carrying state in a direction the tree does not point.
;; Keeping the number FLAT -- a vector of (value, depth) -- turns that into "the previous
;; element", and every rewrite into a vector rebuild. The reference implementation makes the same
;; choice for the same reason, so nothing here turns on wat.
;;
;; What wat contributes is the rebuild. Explode and split each replace a slice of the vector, and
;; with no positional update (F-104) and no `subvec` (F-116) every one of them copies the whole
;; number. The numbers here are at most 61 characters, so the copies cost nothing -- the same
;; size argument days 8, 10 and 15 make, and the opposite of what C-113 measured past 256.
;;
;; The puzzle and its input are ours (aoc/input/day18-snailfish.txt); Advent of Code's own texts
;; and inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day18-snailfish.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day18-snailfish.wat

(:wat::load-file! "lib/check.wat")

;; one regular number, and how deep it sits
(:wat::core::defrecord :aoc::Sn [v <- :wat::core::i64  d <- :wat::core::i64])
(:wat::core::typealias :aoc::Num (:wat::core::Vector :- [:aoc::Sn]))

(:wat::core::defn :aoc::digit? [c <- :wat::core::String] -> :wat::core::bool
  (:wat::string::contains? "0123456789" c))

;; parse by scanning: a bracket changes the depth, a digit is an element at that depth
(:wat::core::defn :aoc::parse [s <- :wat::core::String i <- :wat::core::i64 d <- :wat::core::i64
                               acc <- :aoc::Num] -> :aoc::Num
  (:wat::core::if (:wat::core::>= i (:wat::string::length s)) acc
    (:wat::core::let [c (:wat::string::subs s i (:wat::core::+ i 1))]
      (:wat::core::cond
        ((:wat::core::= c "[") (:aoc::parse s (:wat::core::+ i 1) (:wat::core::+ d 1) acc))
        ((:wat::core::= c "]") (:aoc::parse s (:wat::core::+ i 1) (:wat::core::- d 1) acc))
        ((:wat::core::= c ",") (:aoc::parse s (:wat::core::+ i 1) d acc))
        (:else (:aoc::parse s (:wat::core::+ i 1) d
                 (:wat::core::conj acc (:aoc::Sn :v (:aoc::to-int c) :d d))))))))

;; ---- the rebuilds. Each one copies the number; the numbers are tens of elements long.
(:wat::core::defn :aoc::rebuild [f <- :aoc::Num from <- :wat::core::i64 to <- :wat::core::i64
                                 mid <- :aoc::Num add-left <- :wat::core::i64
                                 add-right <- :wat::core::i64 j <- :wat::core::i64
                                 acc <- :aoc::Num] -> :aoc::Num
  ;; everything before `from` (the element just before it gains `add-left`), then `mid`, then
  ;; everything from `to` (the first of them gains `add-right`)
  (:wat::core::if (:wat::core::>= j (:wat::core::length f)) acc
    (:wat::core::let
      [e (:wat::core::nth f j)
       keep (:wat::core::or (:wat::core::< j from) (:wat::core::>= j to))
       bump (:wat::core::cond
              ((:wat::core::= j (:wat::core::- from 1)) add-left)
              ((:wat::core::= j to) add-right)
              (:else 0))]
      (:aoc::rebuild f from to mid add-left add-right (:wat::core::+ j 1)
        (:wat::core::if (:wat::core::= j from) (:wat::core::concat acc mid)
          (:wat::core::if keep
            (:wat::core::conj acc (:wat::core::assoc e :v (:wat::core::+ (:aoc::Sn/v e) bump)))
            acc))))))

(:wat::core::defn :aoc::find-deep [f <- :aoc::Num i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length f)) -1)
    ((:wat::core::> (:aoc::Sn/d (:wat::core::nth f i)) 4) i)
    (:else (:aoc::find-deep f (:wat::core::+ i 1)))))

(:wat::core::defn :aoc::find-big [f <- :aoc::Num i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length f)) -1)
    ((:wat::core::>= (:aoc::Sn/v (:wat::core::nth f i)) 10) i)
    (:else (:aoc::find-big f (:wat::core::+ i 1)))))

(:wat::core::defn :aoc::explode [f <- :aoc::Num i <- :wat::core::i64] -> :aoc::Num
  (:wat::core::let [l (:aoc::Sn/v (:wat::core::nth f i))
                    r (:aoc::Sn/v (:wat::core::nth f (:wat::core::+ i 1)))
                    d (:aoc::Sn/d (:wat::core::nth f i))]
    (:aoc::rebuild f i (:wat::core::+ i 2)
      (:wat::core::Vector :- [:aoc::Sn] (:aoc::Sn :v 0 :d (:wat::core::- d 1)))
      l r 0 (:wat::core::Vector :- [:aoc::Sn]))))

(:wat::core::defn :aoc::split [f <- :aoc::Num i <- :wat::core::i64] -> :aoc::Num
  (:wat::core::let [v (:aoc::Sn/v (:wat::core::nth f i))
                    d (:aoc::Sn/d (:wat::core::nth f i))]
    (:aoc::rebuild f i (:wat::core::+ i 1)
      (:wat::core::Vector :- [:aoc::Sn]
        (:aoc::Sn :v (:wat::core::/ v 2) :d (:wat::core::+ d 1))
        (:aoc::Sn :v (:wat::core::/ (:wat::core::+ v 1) 2) :d (:wat::core::+ d 1)))
      0 0 0 (:wat::core::Vector :- [:aoc::Sn]))))

(:wat::core::defn :aoc::reduce-num [f <- :aoc::Num] -> :aoc::Num
  (:wat::core::let [i (:aoc::find-deep f 0)]
    (:wat::core::if (:wat::core::>= i 0) (:aoc::reduce-num (:aoc::explode f i))
      (:wat::core::let [j (:aoc::find-big f 0)]
        (:wat::core::if (:wat::core::>= j 0) (:aoc::reduce-num (:aoc::split f j)) f)))))

(:wat::core::defn :aoc::deepen [f <- :aoc::Num i <- :wat::core::i64 acc <- :aoc::Num] -> :aoc::Num
  (:wat::core::if (:wat::core::>= i (:wat::core::length f)) acc
    (:wat::core::let [e (:wat::core::nth f i)]
      (:aoc::deepen f (:wat::core::+ i 1)
        (:wat::core::conj acc (:wat::core::assoc e :d (:wat::core::+ (:aoc::Sn/d e) 1)))))))

(:wat::core::defn :aoc::add [a <- :aoc::Num b <- :aoc::Num] -> :aoc::Num
  (:aoc::reduce-num
    (:wat::core::concat (:aoc::deepen a 0 (:wat::core::Vector :- [:aoc::Sn]))
                        (:aoc::deepen b 0 (:wat::core::Vector :- [:aoc::Sn])))))

;; magnitude: collapse the deepest adjacent pair until one element is left
(:wat::core::defn :aoc::max-depth [f <- :aoc::Num i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length f)) acc
    (:aoc::max-depth f (:wat::core::+ i 1)
      (:wat::core::if (:wat::core::> (:aoc::Sn/d (:wat::core::nth f i)) acc)
        (:aoc::Sn/d (:wat::core::nth f i)) acc))))

(:wat::core::defn :aoc::find-pair [f <- :aoc::Num m <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= (:wat::core::+ i 1) (:wat::core::length f)) -1)
    ((:wat::core::and (:wat::core::= (:aoc::Sn/d (:wat::core::nth f i)) m)
                      (:wat::core::= (:aoc::Sn/d (:wat::core::nth f (:wat::core::+ i 1))) m)) i)
    (:else (:aoc::find-pair f m (:wat::core::+ i 1)))))

(:wat::core::defn :aoc::magnitude [f <- :aoc::Num] -> :wat::core::i64
  (:wat::core::if (:wat::core::= (:wat::core::length f) 1) (:aoc::Sn/v (:wat::core::nth f 0))
    (:wat::core::let [m (:aoc::max-depth f 0 0)
                      i (:aoc::find-pair f m 0)
                      v (:wat::core::+ (:wat::core::* 3 (:aoc::Sn/v (:wat::core::nth f i)))
                                       (:wat::core::* 2 (:aoc::Sn/v (:wat::core::nth f (:wat::core::+ i 1)))))]
      (:aoc::magnitude
        (:aoc::rebuild f i (:wat::core::+ i 2)
          (:wat::core::Vector :- [:aoc::Sn] (:aoc::Sn :v v :d (:wat::core::- m 1)))
          0 0 0 (:wat::core::Vector :- [:aoc::Sn]))))))

(:wat::core::typealias :aoc::Nums (:wat::core::Vector :- [:aoc::Num]))

(:wat::core::defn :aoc::sum-all [ns <- :aoc::Nums i <- :wat::core::i64 acc <- :aoc::Num] -> :aoc::Num
  (:wat::core::if (:wat::core::>= i (:wat::core::length ns)) acc
    (:aoc::sum-all ns (:wat::core::+ i 1) (:aoc::add acc (:wat::core::nth ns i)))))

(:wat::core::defn :aoc::best-pair [ns <- :aoc::Nums i <- :wat::core::i64 j <- :wat::core::i64
                                   acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length ns)) acc)
    ((:wat::core::>= j (:wat::core::length ns)) (:aoc::best-pair ns (:wat::core::+ i 1) 0 acc))
    ((:wat::core::= i j) (:aoc::best-pair ns i (:wat::core::+ j 1) acc))
    (:else
      (:wat::core::let [m (:aoc::magnitude (:aoc::add (:wat::core::nth ns i) (:wat::core::nth ns j)))]
        (:aoc::best-pair ns i (:wat::core::+ j 1) (:wat::core::if (:wat::core::> m acc) m acc))))))

(:wat::core::defn :aoc::parse-all [ls <- :aoc::Lines i <- :wat::core::i64 acc <- :aoc::Nums] -> :aoc::Nums
  (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) acc
    (:aoc::parse-all ls (:wat::core::+ i 1)
      (:wat::core::conj acc (:aoc::parse (:wat::core::nth ls i) 0 0 (:wat::core::Vector :- [:aoc::Sn]))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [ns (:aoc::parse-all (:aoc::lines "aoc/input/day18-snailfish.txt") 0 (:wat::core::Vector :- [:aoc::Num]))
     total (:aoc::sum-all ns 1 (:wat::core::nth ns 0))
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day18-snailfish.expected"
                         "aoc day18 snailfish"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::magnitude total))
                           (int (:aoc::best-pair ns 0 0 0))))))
